#!/usr/bin/env bats

@test "clean.sh executes successfully" {
    run ./scripts/clean.sh
    [ "$status" -eq 0 ]
}

@test "clean.sh prints completion message" {
    run ./scripts/clean.sh
    [[ "$output" == *"Cleanup completed successfully."* ]]
}