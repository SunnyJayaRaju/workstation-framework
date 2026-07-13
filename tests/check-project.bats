#!/usr/bin/env bats

@test "check-project.sh executes successfully" {
    run ./scripts/check-project.sh

    [ "$status" -eq 0 ]
}

@test "check-project.sh prints success message" {
    run ./scripts/check-project.sh

    [[ "$output" == *"Repository structure verified."* ]]
}