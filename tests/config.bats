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
