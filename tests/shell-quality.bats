#!/usr/bin/env bats

@test "shell-quality.sh requires an argument" {
    run bash scripts/shell-quality.sh

    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shell-quality.sh works with a valid script" {
    run bash scripts/shell-quality.sh scripts/lib/errors.sh

    [ "$status" -eq 0 ]
}