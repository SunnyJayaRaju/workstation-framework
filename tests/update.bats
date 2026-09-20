#!/usr/bin/env bats

load test_helper

@test "update.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/update.sh"
    [ "$status" -eq 0 ]
}