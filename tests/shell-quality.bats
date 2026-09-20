#!/usr/bin/env bats

load test_helper

@test "shell-quality.sh requires an argument" {
    run bash "${SCRIPTS_DIR}/shell-quality.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shell-quality.sh works with a valid script" {
    run bash "${SCRIPTS_DIR}/shell-quality.sh" "${SCRIPTS_DIR}/lib/errors.sh"

    [ "$status" -eq 0 ]
}