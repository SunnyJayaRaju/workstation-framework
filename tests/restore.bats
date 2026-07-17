#!/usr/bin/env bats

@test "restore.sh executes successfully" {
    run ./scripts/restore.sh

    [ "$status" -eq 0 ]
}

@test "restore.sh prints completion message" {
    run ./scripts/restore.sh

    [[ "$output" == *"Restore completed successfully."* ]]
}