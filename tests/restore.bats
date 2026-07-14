#!/usr/bin/env bats

@test "restore.sh executes successfully" {
    run ./scripts/restore.sh
    [ "$status" -eq 0 ]
}