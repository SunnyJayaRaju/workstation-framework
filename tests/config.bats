#!/usr/bin/env bats

load test_helper

@test "config directory exists" {
    source "${SCRIPTS_DIR}/lib/config.sh"

    run config_exists

    [ "$status" -eq 0 ]
}

@test "default configuration loads" {
    source "${SCRIPTS_DIR}/lib/config.sh"

    load_config

    [ "$INSTALL_DIR" = "$HOME/.local/bin" ]
    [ "$BACKUP_DIR" = "$HOME/.workstation/backups" ]
}

@test "LOG_LEVEL accepts a level name without suppressing output" {
    # A name like "info" used to be arithmetic-evaluated as an undefined
    # variable (0), which silently dropped INFO and PASS lines.
    run env LOG_LEVEL=info bash -c \
        "source '${SCRIPTS_DIR}/lib/logging.sh'; log_info 'hello-info'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello-info"* ]]
}

@test "LOG_LEVEL=debug shows debug output" {
    run env LOG_LEVEL=debug bash -c \
        "source '${SCRIPTS_DIR}/lib/logging.sh'; log_debug 'hello-debug'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello-debug"* ]]
}

@test "LOG_LEVEL=error suppresses info output" {
    run env LOG_LEVEL=error bash -c \
        "source '${SCRIPTS_DIR}/lib/logging.sh'; log_info 'should-not-appear'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"should-not-appear"* ]]
}

@test "LOG_LEVEL still accepts plain numbers" {
    run env LOG_LEVEL=3 bash -c \
        "source '${SCRIPTS_DIR}/lib/logging.sh'; log_debug 'num-debug'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"num-debug"* ]]
}

@test "an invalid LOG_LEVEL fails loudly instead of eating output" {
    run env LOG_LEVEL=bogus bash -c "source '${SCRIPTS_DIR}/lib/logging.sh'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"LOG_LEVEL"* ]]
}
# --- FIX 4: a missing config file is reported, not silent (M11) ----------

@test "load_config warns when the expected config file is missing" {
    # A copy of the library with no sibling config/ directory, so the real
    # repository's config/default.conf cannot satisfy it.
    local lonely="${BATS_TEST_TMPDIR}/a/b/lib"
    mkdir -p "$lonely"
    cp "${SCRIPTS_DIR}/lib/config.sh" "${lonely}/config.sh"
    cp "${SCRIPTS_DIR}/lib/errors.sh" "${lonely}/errors.sh"
    cp "${SCRIPTS_DIR}/lib/logging.sh" "${lonely}/logging.sh"

    run env HOME="$BATS_TEST_TMPDIR}/nohome" bash -c \
        "source '${lonely}/config.sh'; load_config"

    # names the file that was looked for
    [[ "$output" == *"default.conf"* ]]
    [[ "$output" == *"not found"* || "$output" == *"missing"* ]]
}

@test "load_config warns when user.conf is missing but default.conf exists" {
    local partial="${BATS_TEST_TMPDIR}/partial/x/lib"
    mkdir -p "${partial}/../../config"
    cp "${SCRIPTS_DIR}/lib/config.sh" "${partial}/config.sh"
    cp "${SCRIPTS_DIR}/lib/errors.sh" "${partial}/errors.sh"
    cp "${SCRIPTS_DIR}/lib/logging.sh" "${partial}/logging.sh"
    printf 'INSTALL_DIR="/tmp/x"\n' >"${partial}/../../config/default.conf"

    run env HOME="$BATS_TEST_TMPDIR}/nohome" bash -c \
        "source '${partial}/config.sh'; load_config"

    [[ "$output" == *"user.conf"* ]]
}

@test "load_config is quiet when both config files exist" {
    run env HOME="$BATS_TEST_TMPDIR}/nohome" bash -c \
        "source '${SCRIPTS_DIR}/lib/config.sh'; load_config"
    [ "$status" -eq 0 ]
    [[ "$output" != *"not found"* ]]
}

# --- FIX 5: JSON log output must be escaped (M12) ------------------------

@test "LOG_FORMAT=json produces parseable JSON for a hostile message" {
    command -v jq >/dev/null 2>&1 || skip "jq not installed"

    # Built in a helper script so the quote, backslash and newline survive
    # without being mangled by layers of nested shell quoting.
    local helper="${BATS_TEST_TMPDIR}/log-hostile.sh"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        "source '${SCRIPTS_DIR}/lib/logging.sh'" \
        "msg=\$'quote=\" back\\\\slash and\\nnewline'" \
        'log_info "$msg"' >"$helper"

    run env LOG_FORMAT=json bash "$helper"
    [ "$status" -eq 0 ]

    # must parse as JSON
    run jq -e . <<<"$output"
    [ "$status" -eq 0 ]

    # and the original content must be recoverable
    run jq -r '.message' <<<"$output"
    [[ "$output" == *'quote="'* ]]
    [[ "$output" == *'back\slash'* ]]
    [[ "$output" == *$'\n'* ]]
}

@test "LOG_FORMAT=json cannot be used to inject an extra field" {
    command -v jq >/dev/null 2>&1 || skip "jq not installed"

    run env LOG_FORMAT=json bash -c \
        "source '${SCRIPTS_DIR}/lib/logging.sh'; log_info 'x\",\"injected\":\"yes'"
    [ "$status" -eq 0 ]

    run jq -e . <<<"$output"
    [ "$status" -eq 0 ]

    # the injected key must not exist as a real field
    run jq -r '.injected // "ABSENT"' <<<"$output"
    [ "$output" = "ABSENT" ]
}

@test "json_escape is applied to every interpolated field" {
    source "${SCRIPTS_DIR}/lib/logging.sh"

    run json_escape 'plain'
    [ "$output" = "plain" ]

    run json_escape 'a"b'
    [ "$output" = 'a\"b' ]

    run json_escape 'a\b'
    [ "$output" = 'a\\b' ]

    run json_escape $'line1\nline2'
    [ "$output" = 'line1\nline2' ]
}

# --- FIX 5: direct tests for the config parser (M16) -------------------
# config.sh is the security control that keeps INSTALL_DIR/BACKUP_DIR safe:
# it parses KEY=VALUE instead of sourcing the file. These are its first
# direct tests, and each hostile case also asserts the value WAS read as
# literal text, so the test cannot pass merely because loading failed.

# A standalone copy of config.sh with its own config dir, so the real
# repository config cannot satisfy it. CONFIG_DIR resolves to
# <base>/a/config because config.sh is at <base>/a/b/lib/config.sh.
standalone_config() {
    local base="${BATS_TEST_TMPDIR}/cfg-$1"
    mkdir -p "${base}/a/b/lib" "${base}/a/config"
    cp "${SCRIPTS_DIR}/lib/config.sh" "${base}/a/b/lib/config.sh"
    cp "${SCRIPTS_DIR}/lib/logging.sh" "${base}/a/b/lib/logging.sh"
    printf '%s' "${base}"
}

load_key() {
    # load_key <config.sh path> <KEY>
    env HOME="$BATS_TEST_TMPDIR/nohome" bash -c \
        "source '$1'; load_config; printf '%s' \"\${$2}\""
}

@test "config parser strips surrounding quotes from values" {
    local base
    base="$(standalone_config strip-quotes)"
    printf 'SOMEKEY="quoted value"\n' >"${base}/a/config/default.conf"

    run --separate-stderr load_key "${base}/a/b/lib/config.sh" SOMEKEY
    [ "$status" -eq 0 ]
    [ "$output" = "quoted value" ]
}

@test "config parser expands $HOME in values" {
    local base
    base="$(standalone_config expand-home)"
    printf 'SOMEKEY="$HOME/thing"\n' >"${base}/a/config/default.conf"

    run --separate-stderr load_key "${base}/a/b/lib/config.sh" SOMEKEY
    [ "$status" -eq 0 ]
    [ "$output" = "$BATS_TEST_TMPDIR/nohome/thing" ]
}

@test "config parser reads command substitution as literal text, never executing it" {
    local base canary
    base="$(standalone_config no-subst)"
    canary="${BATS_TEST_TMPDIR}/pwned-marker"
    printf 'SOMEKEY="$(touch %s)"\n' "$canary" >"${base}/a/config/default.conf"

    run --separate-stderr load_key "${base}/a/b/lib/config.sh" SOMEKEY

    # not executed
    [ ! -e "$canary" ]
    # but genuinely parsed: the raw text came through unchanged
    [ "$output" = "\$(touch $canary)" ]
}

@test "config parser reads backticks as literal text, never executing them" {
    local base canary
    base="$(standalone_config no-backtick)"
    canary="${BATS_TEST_TMPDIR}/pwned-backtick"
    printf 'SOMEKEY="`touch %s`"\n' "$canary" >"${base}/a/config/default.conf"

    run --separate-stderr load_key "${base}/a/b/lib/config.sh" SOMEKEY

    [ ! -e "$canary" ]
    [ "$output" = "\`touch $canary\`" ]
}

@test "config parser treats semicolons as literal text, not command separators" {
    local base canary
    base="$(standalone_config no-semicolon)"
    canary="${BATS_TEST_TMPDIR}/pwned-semicolon"
    printf 'SOMEKEY="x; touch %s"\n' "$canary" >"${base}/a/config/default.conf"

    run --separate-stderr load_key "${base}/a/b/lib/config.sh" SOMEKEY

    [ ! -e "$canary" ]
    [ "$output" = "x; touch $canary" ]
}

@test "config parser skips lines that are not KEY=VALUE and keeps parsing" {
    local base canary
    base="$(standalone_config bad-key)"
    canary="${BATS_TEST_TMPDIR}/pwned-badkey"
    {
        printf 'rm -rf %s\n' "$canary"
        printf 'GOODKEY="still-parsed"\n'
    } >"${base}/a/config/default.conf"

    run --separate-stderr load_key "${base}/a/b/lib/config.sh" GOODKEY

    # the malformed line was ignored entirely
    [ ! -e "$canary" ]
    # positive control: parsing continued to the next valid line
    [ "$output" = "still-parsed" ]
}

@test "safe_expand substitutes known variables only" {
    run env MYVAR=hello bash -c \
        "source '${SCRIPTS_DIR}/lib/config.sh'; safe_expand 'v=\$MYVAR'"
    [[ "$output" == *"v=hello"* ]]

    run env bash -c \
        "source '${SCRIPTS_DIR}/lib/config.sh'; safe_expand 'v=\${NOPE_UNDEFINED}'"
    [[ "$output" == *"v="* ]]
}

@test "environment variables take precedence over config values" {
    local base
    base="$(standalone_config precedence)"
    printf 'PRECEDENCE="from-config"\n' >"${base}/a/config/default.conf"

    run --separate-stderr env PRECEDENCE="from-env" HOME="$BATS_TEST_TMPDIR/nohome" bash -c \
        "source '${base}/a/b/lib/config.sh'; load_config; printf '%s' \"\$PRECEDENCE\""
    [ "$output" = "from-env" ]
}
