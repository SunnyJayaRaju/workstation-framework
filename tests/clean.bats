#!/usr/bin/env bats

load test_helper

setup() {
    # Copy repo-clean.sh and its dependencies to a temp location to avoid macOS quarantine
    REPO_CLEAN_TEMP_DIR="$(mktemp -d)"
    cp -R "${SCRIPTS_DIR}/." "${REPO_CLEAN_TEMP_DIR}/"
    chmod +x "${REPO_CLEAN_TEMP_DIR}/repo-clean.sh"
    # Remove any macOS quarantine attributes recursively
    if [[ "$OSTYPE" == "darwin"* ]]; then
        xattr -cr "${REPO_CLEAN_TEMP_DIR}" 2>/dev/null || true
    fi
}

teardown() {
    [[ -n "${REPO_CLEAN_TEMP_DIR}" ]] && rm -rf "${REPO_CLEAN_TEMP_DIR}"
}

@test "repo-clean.sh executes successfully" {
    run bash "${REPO_CLEAN_TEMP_DIR}/repo-clean.sh"
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run bash "${REPO_CLEAN_TEMP_DIR}/repo-clean.sh"
    [[ "$output" == *"Cleanup completed successfully."* ]]
}