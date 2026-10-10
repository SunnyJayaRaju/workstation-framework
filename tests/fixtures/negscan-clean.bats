#!/usr/bin/env bats
@test "clean" {
    run grep -q x /dev/null
    [ "$status" -ne 0 ]
}
