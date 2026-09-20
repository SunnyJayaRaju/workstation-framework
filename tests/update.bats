#!/usr/bin/env bats

@test "update.sh executes successfully" {
    run bash scripts/update.sh
    [ "$status" -eq 0 ]
}