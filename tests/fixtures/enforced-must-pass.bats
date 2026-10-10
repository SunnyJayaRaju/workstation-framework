#!/usr/bin/env bats
@test "enforced form that must pass" {
    run grep -q x "__FILE__"
    [ "$status" -ne 0 ]
}
