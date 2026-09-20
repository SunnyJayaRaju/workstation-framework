#!/usr/bin/env bats

load test_helper

@test "install.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/install.sh"

    [ "$status" -eq 0 ]
}

@test "install.sh prints completion message" {
    run bash "${SCRIPTS_DIR}/install.sh"

    [[ "$output" == *"Installation completed successfully."* ]]
}