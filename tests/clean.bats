#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "repo-clean.sh executes successfully" {
    run bash "$PROJECT_ROOT/scripts/repo-clean.sh"
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run bash "$PROJECT_ROOT/scripts/repo-clean.sh"
    [[ "$output" == *"Cleanup completed successfully."* ]]
}