#!/usr/bin/env bats

load test_helper

@test "repo-clean.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/repo-clean.sh"
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run bash "${SCRIPTS_DIR}/repo-clean.sh"
    [[ "$output" == *"Cleanup completed successfully."* ]]
}