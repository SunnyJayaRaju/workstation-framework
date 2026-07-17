#!/usr/bin/env bats

@test "backup.sh executes successfully" {
    run ./scripts/backup.sh

    [ "$status" -eq 0 ]
}

@test "backup.sh prints completion message" {
    run ./scripts/backup.sh

    [[ "$output" == *"Backup completed successfully."* ]]
}