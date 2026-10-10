#!/usr/bin/env bats
@test "named" {
    [[ "$output" == *"/opt/homebrew/bin/gem update"* ]]
}
