#!/usr/bin/env bats

@test "install.sh executes successfully" {
    run ./scripts/install.sh
    [ "$status" -eq 0 ]
}