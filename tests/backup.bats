#!/usr/bin/env bats

@test "backup.sh executes successfully" {
    run ./scripts/backup.sh
    [ "$status" -eq 0 ]
}