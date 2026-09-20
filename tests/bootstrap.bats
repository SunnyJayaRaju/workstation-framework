#!/usr/bin/env bats

load test_helper

@test "bootstrap.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/bootstrap.sh"

    [ "$status" -eq 0 ]
}

@test "bootstrap.sh prints completion message" {
    run bash "${SCRIPTS_DIR}/bootstrap.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation completed successfully."* ]]
}