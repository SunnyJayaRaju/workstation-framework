#!/usr/bin/env bats

@test "repo-clean.sh executes successfully" {
    run ./scripts/repo-clean.sh
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run ./scripts/repo-clean.sh
    [[ "$output" == *"Cleanup completed successfully."* ]]
}