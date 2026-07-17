#!/usr/bin/env bats

@test "install.sh executes successfully" {
    run ./scripts/install.sh

    [ "$status" -eq 0 ]
}

@test "install.sh prints completion message" {
    run ./scripts/install.sh

    [[ "$output" == *"Installation completed successfully."* ]]
}