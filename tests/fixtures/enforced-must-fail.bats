#!/usr/bin/env bats
@test "enforced form that MUST fail" {
    run grep -q x "__FILE__"
    [ "$status" -ne 0 ]
}
