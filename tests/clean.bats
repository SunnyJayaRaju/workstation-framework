#!/usr/bin/env bats

@test "repo-clean.sh executes successfully" {
    run bash scripts/repo-clean.sh
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run bash scripts/repo-clean.sh
    [[ "$output" == *"Cleanup completed successfully."* ]]
}