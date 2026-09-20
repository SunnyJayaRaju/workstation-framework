#!/usr/bin/env bats

@test "sync.sh executes successfully" {
    run bash scripts/sync.sh

    [ "$status" -eq 0 ]
}

@test "sync.sh prints completion message" {
    run bash scripts/sync.sh

    [[ "$output" == *"Synchronization check completed."* ]]
}