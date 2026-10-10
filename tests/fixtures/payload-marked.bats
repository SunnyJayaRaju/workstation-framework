#!/usr/bin/env bats
@test "assert the guard refuses this" {
    eval "gem list"
    [ "$output" = "sudo gem update --system" ] # safety: asserted as a string, never run
}
