#!/usr/bin/env bats

@test "shell-quality.sh requires an argument" {
    run ./scripts/shell-quality.sh

    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shell-quality.sh works with a valid script" {
    run ./scripts/shell-quality.sh ./scripts/check-project.sh

    [ "$status" -eq 0 ]
}