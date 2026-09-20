#!/usr/bin/env bats

load test_helper

@test "check-project.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/check-project.sh"

    [ "$status" -eq 0 ]
}

@test "check-project.sh prints success message" {
    run bash "${SCRIPTS_DIR}/check-project.sh"

    [[ "$output" == *"Repository structure verified."* ]]
}