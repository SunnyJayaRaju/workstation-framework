#!/usr/bin/env bats
@test "planted-negation" {
    echo hi
    ! grep -q x /dev/null
}
