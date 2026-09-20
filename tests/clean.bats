#!/usr/bin/env bats

load test_helper

setup() {
    # Remove macOS quarantine attribute from repo-clean.sh if present
    if [[ "$OSTYPE" == "darwin"* ]]; then
        xattr -d com.apple.quarantine "${SCRIPTS_DIR}/repo-clean.sh" 2>/dev/null || true
        xattr -d com.apple.quarantine "$(dirname "${SCRIPTS_DIR}/repo-clean.sh")" 2>/dev/null || true
    fi
}

@test "repo-clean.sh executes successfully" {
    run bash -c "source ${SCRIPTS_DIR}/repo-clean.sh"
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run bash -c "source ${SCRIPTS_DIR}/repo-clean.sh"
    [[ "$output" == *"Cleanup completed successfully."* ]]
}