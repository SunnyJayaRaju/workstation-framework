#!/usr/bin/env bats

load test_helper

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    export INSTALL_DIR="${BATS_TEST_TMPDIR}/install"
    mkdir -p "$HOME" "$INSTALL_DIR"

    STUB_BIN="${BATS_TEST_TMPDIR}/stubbin"
    mkdir -p "$STUB_BIN"
    STUB_LOG="${BATS_TEST_TMPDIR}/stub.log"
    : >"$STUB_LOG"
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
    printf '#!/usr/bin/env bash\necho "%s" >&2\nexit %s\n' "$3" "$2" \
        >"${STUB_BIN}/$1"
    chmod +x "${STUB_BIN}/$1"
}

# --- M3: jq is required for the 1Password read path ---------------------

@test "get_secret fails with a jq diagnostic when the 1Password path is used without jq" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    local safe
    safe="$(minimal_path)"
    # `op` present and signed in, so the 1Password branch is taken...
    link_stub op 0 ""
    # ...but jq is absent from the minimal PATH.
    # -u SECRETS_LOADED: secrets.sh exports its load guard, so without this the
    # child's `source` is a silent no-op and get_secret would not exist.
    run env -u SECRETS_LOADED PATH="${STUB_BIN}:${safe}" bash -c \
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

    PATH="${STUB_BIN}:${PATH}" run store_secret_op "Item" "field" "value"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not sign in"* ]]
}

@test "delete_secret surfaces security stderr and fails on error" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    link_stub security 1 "SecKeychainSearchCopyNext: item not found"

    PATH="${STUB_BIN}:${PATH}" run delete_secret "no-such-secret"
    [ "$status" -ne 0 ]
    [[ "$output" == *"SecKeychainSearchCopyNext"* ]]
    # guards against matching bash's own "command not found"
    [[ "$output" != *"command not found"* ]]
}

@test "delete_secret does not report success when nothing was removed" {
    source "${SCRIPTS_DIR}/lib/secrets.sh"

    link_stub security 1 "boom"

    PATH="${STUB_BIN}:${PATH}" run delete_secret "no-such-secret"
    # must NOT look like a clean success
    [[ "$output" != *"removed"* ]]
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