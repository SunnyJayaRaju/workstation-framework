#!/usr/bin/env bats

@test "doctor.sh executes successfully" {
    run ./scripts/doctor.sh

    [ "$status" -eq 0 ]
}

@test "doctor.sh prints completion message" {
    run ./scripts/doctor.sh

    [[ "$output" == *"Doctor completed."* ]]
}