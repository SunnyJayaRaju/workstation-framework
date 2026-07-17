#!/usr/bin/env bats

@test "sync.sh executes successfully" {
    run ./scripts/sync.sh

    [ "$status" -eq 0 ]
}

@test "sync.sh prints completion message" {
    run ./scripts/sync.sh

    [[ "$output" == *"Synchronization check completed."* ]]
}