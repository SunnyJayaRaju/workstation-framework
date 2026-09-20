#!/usr/bin/env bats

load test_helper

@test "sync.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/sync.sh"

    [ "$status" -eq 0 ]
}

@test "sync.sh prints completion message" {
    run bash "${SCRIPTS_DIR}/sync.sh"

    [[ "$output" == *"Synchronization check completed."* ]]
}