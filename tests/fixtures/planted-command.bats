#!/usr/bin/env bats
load test_helper
@test "planted-command-line" {
    run gem update --system
}
