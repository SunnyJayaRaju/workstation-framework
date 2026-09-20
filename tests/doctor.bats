#!/usr/bin/env bats

load test_helper

@test "doctor.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/doctor.sh"

    [ "$status" -eq 0 ]
}

@test "doctor.sh prints completion message" {
    run bash "${SCRIPTS_DIR}/doctor.sh"

    [[ "$output" == *"Doctor completed."* ]]
}