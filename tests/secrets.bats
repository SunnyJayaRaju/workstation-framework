#!/usr/bin/env bats

load test_helper

setup() {
    # A unique service name per test, so nothing here ever writes to the real
    # "workstation-framework" service the framework uses in production.
    export KC_SERVICE="workstation-framework-test-${BATS_TEST_NUMBER}"
    export KC_ACCOUNT="probe"
    KC_ACCOUNTS=()

    source "${SCRIPTS_DIR}/lib/secrets.sh"
}

# Track an account so teardown can delete it even if an assertion fails.
kc_track() {
    KC_ACCOUNTS+=("$1")
}

teardown() {
    # Unconditional cleanup: teardown runs even when the test fails, so a red
    # test cannot leave items in the developer's real login Keychain.
    #
    # NOTE: reading Keychain items back can raise a macOS GUI authorisation
    # prompt on some systems. That is deliberately NOT suppressed here — this
    # suite genuinely talks to the real login Keychain, and hiding the prompt
    # would hide the fact that it is happening.
    if [[ "$OSTYPE" == darwin* ]] && command -v security >/dev/null 2>&1; then
        local acct
        for acct in "${KC_ACCOUNTS[@]:-}"; do
            security delete-generic-password -s "$KC_SERVICE" -a "$acct" \
                >/dev/null 2>&1 || true
        done
    fi
}

# A PATH containing only the handful of commands the scripts need, so that a
# tool we want to be "missing" genuinely is.
minimal_path() {
    local dir="${BATS_TEST_TMPDIR}/minpath"
    mkdir -p "$dir"
    local c
    for c in bash env dirname basename date command cat printf grep sed head; do
        ln -sf "$(command -v "$c")" "${dir}/$c"
    done
    echo "$dir"
}

link_stub() {
    # link_stub <name> <exit-code> <stderr-message>
    mkdir -p "${BATS_TEST_TMPDIR}/stubbin"
    printf '#!/usr/bin/env bash\necho "%s" >&2\nexit %s\n' "$3" "$2" \
        >"${BATS_TEST_TMPDIR}/stubbin/$1"
    chmod +x "${BATS_TEST_TMPDIR}/stubbin/$1"
}

# --- library basics -----------------------------------------------------

@test "secrets.sh loads without error" {
    [ -n "${SECRETS_LOADED:-}" ]
}

@test "has_keychain returns true on macOS" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run has_keychain
        [ "$status" -eq 0 ]
    else
        skip "Keychain only available on macOS"
    fi
}

@test "get_secret falls back to environment variable" {
    export TEST_SECRET_VALUE="from-env"
    run get_secret "test-secret-value"
    [ "$status" -eq 0 ]
    [ "$output" = "from-env" ]
}

@test "get_secret returns non-zero for unknown secret with no fallback" {
    unset NONEXISTENT_SECRET || true
    run get_secret "nonexistent-secret"
    [ "$status" -ne 0 ]
}

# --- Keychain round-trip, isolated from the production service ----------

@test "store_secret_keychain and get_secret_keychain round-trip (macOS only)" {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        skip "Keychain only available on macOS"
    fi

    kc_track "$KC_ACCOUNT"
    store_secret_keychain "$KC_SERVICE" "$KC_ACCOUNT" "roundtrip-value"

    run get_secret_keychain "$KC_SERVICE" "$KC_ACCOUNT"
    [ "$status" -eq 0 ]
    [ "$output" = "roundtrip-value" ]
    # teardown removes it whether or not the assertions above pass
}

@test "Keychain tests never write to the production service name" {
    # Guards the isolation this file depends on: nothing should store under
    # the real "workstation-framework" service.
    [ "$KC_SERVICE" != "workstation-framework" ]
}

# --- injection ----------------------------------------------------------

@test "get_secret rejects command injection in secret name" {
    # Secret names with command substitution should not execute (treated as
    # literal). Read-only, so nothing is stored.
    run get_secret '"'"'$(nonexistent-command-injection-test)'"'"'
    [ "$status" -ne 0 ]
    [[ "$output" != *"injection"* ]]
}

@test "store_secret_keychain does not execute an injected account name" {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        skip "Keychain only available on macOS"
    fi

    kc_track '$(echo exploited)'
    run store_secret_keychain "$KC_SERVICE" '$(echo exploited)' "value"

    # Quoting means it is stored literally rather than executed, so success is
    # fine; what matters is that no output was produced by the injected
    # command. teardown deletes the literal-named item either way.
    [[ "$output" != *"exploited"* ]]

    # and the account really is stored under its literal name
    run get_secret_keychain "$KC_SERVICE" '$(echo exploited)'
    [ "$status" -eq 0 ]
    [ "$output" = "value" ]
}

# --- M3: jq is required for the 1Password read path ----------------------

@test "get_secret fails with a jq diagnostic when the 1Password path is used without jq" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    local safe
    safe="$(minimal_path)"
    # `op` present and signed in, so the 1Password branch is taken...
    link_stub op 0 ""
    # ...but jq is absent from the minimal PATH.
    # -u SECRETS_LOADED: secrets.sh exports its load guard, so without this the
    # child's `source` is a silent no-op and get_secret would not exist.
    run env -u SECRETS_LOADED PATH="${BATS_TEST_TMPDIR}/stubbin:${safe}" bash -c \
        "source '${SCRIPTS_DIR}/lib/secrets.sh'; get_secret 'some-token'"

    # EX_UNAVAILABLE (69), not a bare-name `exit EX_UNAVAILABLE` shell error
    [ "$status" -eq 69 ]
    [[ "$output" == *"jq"* ]]
    [[ "$output" != *"numeric argument required"* ]]
}

@test "has_jq reports jq availability" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    run has_jq
    [ "$status" -eq 0 ]

    local safe
    safe="$(minimal_path)"
    PATH="$safe" run has_jq
    [ "$status" -ne 0 ]
}

@test "README and doctor.sh both declare jq" {
    run grep -q 'jq' "${PROJECT_ROOT}/README.md"
    [ "$status" -eq 0 ]

    run grep -q 'jq' "${SCRIPTS_DIR}/doctor.sh"
    [ "$status" -eq 0 ]
}

@test "doctor.sh reports jq missing and exits non-zero without it" {
    local safe
    safe="$(minimal_path)"

    PATH="$safe" run bash "${SCRIPTS_DIR}/doctor.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"jq missing"* ]]
}

# --- M4: op/security failures are surfaced, not discarded ---------------

@test "store_secret_op surfaces op stderr and fails on error" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    link_stub op 1 "op: could not sign in"

    PATH="${BATS_TEST_TMPDIR}/stubbin:${PATH}" run store_secret_op "Item" "field" "value"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not sign in"* ]]
}

@test "delete_secret surfaces security stderr and fails on error" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    link_stub security 1 "SecKeychainSearchCopyNext: item not found"

    PATH="${BATS_TEST_TMPDIR}/stubbin:${PATH}" run delete_secret "no-such-secret"
    [ "$status" -ne 0 ]
    [[ "$output" == *"SecKeychainSearchCopyNext"* ]]
    # guards against matching bash's own "command not found"
    [[ "$output" != *"command not found"* ]]
}

@test "delete_secret does not report success when nothing was removed" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    link_stub security 1 "boom"

    PATH="${BATS_TEST_TMPDIR}/stubbin:${PATH}" run delete_secret "no-such-secret"
    [[ "$output" != *"removed"* ]]
}

# --- FIX 2: the load guard must not leak into child environments ---------

@test "secrets.sh defines its functions in a child shell" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    # A child inheriting the environment must NOT take the "already loaded"
    # early-return path and end up with no functions at all.
    run env bash -c \
        "source '${SCRIPTS_DIR}/lib/secrets.sh'; declare -F get_secret >/dev/null && echo DEFINED || echo MISSING"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEFINED"* ]]
}

@test "secrets.sh does not export its load guard" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    run env bash -c 'echo "guard=[${SECRETS_LOADED:-unset}]"'
    [[ "$output" == *"guard=[unset]"* ]]
}

@test "secrets.sh call sites document the argv exposure" {
    # `security add-generic-password` and `op item create` have no argv-free
    # non-interactive form for these subcommands, so the process-table
    # exposure is documented at the call site rather than engineered away.
    run grep -qiE 'argv|process table|ps -' "${PROJECT_ROOT}/scripts/lib/secrets.sh"
    [ "$status" -eq 0 ]

    run grep -qiE 'argv|process table|ps -' "${PROJECT_ROOT}/docs/ARCHITECTURE.md"
    [ "$status" -eq 0 ]
}