#!/usr/bin/env bats

@test "update.sh executes successfully" {
    run ./scripts/update.sh
    [ "$status" -eq 0 ]
}