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