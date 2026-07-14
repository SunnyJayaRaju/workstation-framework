#!/usr/bin/env bats

@test "sync.sh executes successfully" {
    run ./scripts/sync.sh
    [ "$status" -eq 0 ]
}