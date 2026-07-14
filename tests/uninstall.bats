#!/usr/bin/env bats

@test "uninstall.sh executes successfully" {
    run ./scripts/uninstall.sh
    [ "$status" -eq 0 ]
}