#!/usr/bin/env bats
@test "mid-test bare negation that MUST fail and does not" {
    ! grep -q x "__FILE__"
    echo "reached the statement AFTER the bare !"
}
