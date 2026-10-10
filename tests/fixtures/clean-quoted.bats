#!/usr/bin/env bats
load test_helper
@test "asserts on the refused text" {
    # a comment mentioning gem update --system and sudo brew
    [[ "$output" == *"gem update --system"* ]]
    [[ "$output" == *"sudo brew upgrade"* ]]
    [[ "$output" == *"brew upgrade"* ]]
}
