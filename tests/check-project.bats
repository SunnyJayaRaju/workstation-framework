#!/usr/bin/env bats

@test "check-project.sh executes successfully" {
    run ./scripts/check-project.sh

    [ "$status" -eq 0 ]

    [[ "$output" == *"Repository structure verified."* ]]
}