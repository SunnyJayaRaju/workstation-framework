#!/usr/bin/env bats

load test_helper

@test "uninstall.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]
}