#!/usr/bin/env bats

@test "uninstall.sh executes successfully" {
    run bash scripts/uninstall.sh
    [ "$status" -eq 0 ]
}