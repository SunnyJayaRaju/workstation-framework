#!/usr/bin/env bats

@test "bootstrap.sh executes successfully" {
    run bash scripts/bootstrap.sh

    [ "$status" -eq 0 ]
}

@test "bootstrap.sh prints completion message" {
    run bash scripts/bootstrap.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation completed successfully."* ]]
}