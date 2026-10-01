#!/usr/bin/env bats

load test_helper

setup() {
    # Hermetic project tree: repo-clean.sh derives PROJECT_ROOT from its own
    # location, so a copy under BATS_TEST_TMPDIR keeps it off the real repo.
    PROJECT_DIR="${BATS_TEST_TMPDIR}/proj"
    mkdir -p "${PROJECT_DIR}/scripts"
    cp -R "${SCRIPTS_DIR}/." "${PROJECT_DIR}/scripts/"
    CLEAN="${PROJECT_DIR}/scripts/repo-clean.sh"
}

@test "repo-clean.sh executes successfully" {
    run bash "$CLEAN"
    [ "$status" -eq 0 ]
}

@test "repo-clean.sh prints completion message" {
    run bash "$CLEAN"
    [[ "$output" == *"Cleanup completed successfully."* ]]
}

@test "repo-clean.sh dry-run shows files without deleting" {
    printf 'a\n' >"${PROJECT_DIR}/one~"

    run bash "$CLEAN" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"one~"* ]]
    [ -f "${PROJECT_DIR}/one~" ]
}

@test "repo-clean.sh deletes a single matching file and reports success" {
    printf 'a\n' >"${PROJECT_DIR}/one~"

    run bash "$CLEAN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cleanup completed successfully."* ]]

    [ ! -e "${PROJECT_DIR}/one~" ]
}

@test "repo-clean.sh deletes every matching file, not just the first" {
    printf 'a\n' >"${PROJECT_DIR}/one~"
    printf 'b\n' >"${PROJECT_DIR}/two.orig"
    printf 'c\n' >"${PROJECT_DIR}/.DS_Store"

    run bash "$CLEAN"

    # The counter must survive set -e inside a command substitution
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed 3 file(s)"* ]]

    [ ! -e "${PROJECT_DIR}/one~" ]
    [ ! -e "${PROJECT_DIR}/two.orig" ]
    [ ! -e "${PROJECT_DIR}/.DS_Store" ]
}