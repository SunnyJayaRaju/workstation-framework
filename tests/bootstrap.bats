#!/usr/bin/env bats

@test "bootstrap.sh executes successfully" {
    run ./scripts/bootstrap.sh

    [ "$status" -eq 0 ]
}

@test "bootstrap.sh prints completion message" {
    run ./scripts/bootstrap.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Bootstrap completed successfully."* ]]
}