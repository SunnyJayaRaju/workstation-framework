#!/usr/bin/env bats

load test_helper

setup() {
    # Hermetic project tree: repo-clean.sh derives PROJECT_ROOT from its own
    # location, so a copy under BATS_TEST_TMPDIR keeps it off the real repo.
    # The tree is git-marked because repo-clean.sh refuses to operate on a
    # directory with no project marker.
    PROJECT_DIR="${BATS_TEST_TMPDIR}/proj"
    mkdir -p "${PROJECT_DIR}/scripts" "${PROJECT_DIR}/.git"
    cp -R "${SCRIPTS_DIR}/." "${PROJECT_DIR}/scripts/"
    CLEAN="${PROJECT_DIR}/scripts/repo-clean.sh"
}

# A copy with NO project marker anywhere above it, i.e. what an installed
# copy at ~/.local/bin looks like: its parent is not a git repository.
make_markerless_copy() {
    MARKERLESS="${BATS_TEST_TMPDIR}/installed-like/bin"
    mkdir -p "$MARKERLESS"
    cp -R "${SCRIPTS_DIR}" "${MARKERLESS}/scripts"
    MARKERLESS_CLEAN="${MARKERLESS}/scripts/repo-clean.sh"
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

    [ "$status" -eq 0 ]
    [[ "$output" == *"3 removed, 0 failed"* ]]

    [ ! -e "${PROJECT_DIR}/one~" ]
    [ ! -e "${PROJECT_DIR}/two.orig" ]
    [ ! -e "${PROJECT_DIR}/.DS_Store" ]
}

@test "repo-clean.sh --verbose does not corrupt the reported count" {
    printf 'a\n' >"${PROJECT_DIR}/one~"
    printf 'b\n' >"${PROJECT_DIR}/two.orig"

    run bash "$CLEAN" --verbose

    [ "$status" -eq 0 ]
    [[ "$output" == *"2 removed, 0 failed"* ]]
    [[ "$output" != *"removed Removing"* ]]
    [[ "$output" == *"Removing:"* ]]

    [ ! -e "${PROJECT_DIR}/one~" ]
    [ ! -e "${PROJECT_DIR}/two.orig" ]
}

# --- FIX 1: a failed removal is reported, and does not stop the rest ------

@test "repo-clean.sh removes the rest and reports a failed removal" {
    printf 'ok\n' >"${PROJECT_DIR}/deletable~"
    printf 'ok\n' >"${PROJECT_DIR}/also-deletable.orig"

    # A file in a non-writable directory: `rm` needs write access to the
    # directory, not the file, so this is how a removal actually fails.
    mkdir -p "${PROJECT_DIR}/locked"
    printf 'stuck\n' >"${PROJECT_DIR}/locked/stuck.orig"
    chmod 555 "${PROJECT_DIR}/locked"

    run bash "$CLEAN"

    # Must continue: the removable files are gone...
    [ ! -e "${PROJECT_DIR}/deletable~" ]
    [ ! -e "${PROJECT_DIR}/also-deletable.orig" ]

    # ...the failure is named...
    [[ "$output" == *"locked/stuck.orig"* ]]

    # ...and the exit code is non-zero
    [ "$status" -ne 0 ]

    chmod 755 "${PROJECT_DIR}/locked"
}

@test "repo-clean.sh reports a succeeded/failed summary" {
    mkdir -p "${PROJECT_DIR}/locked"
    printf 'stuck\n' >"${PROJECT_DIR}/locked/stuck.orig"
    chmod 555 "${PROJECT_DIR}/locked"
    printf 'ok\n' >"${PROJECT_DIR}/fine~"

    run bash "$CLEAN"
    [[ "$output" == *"1 removed"* ]]
    [[ "$output" == *"1 failed"* ]]

    chmod 755 "${PROJECT_DIR}/locked"
}

# --- FIX 2: refuse to operate outside a project; allow --root ------------

@test "repo-clean.sh refuses to run outside a git project by default" {
    make_markerless_copy
    printf 'keep\n' >"${MARKERLESS}/important~"

    run bash "$MARKERLESS_CLEAN"

    [ "$status" -ne 0 ]
    [[ "$output" == *"--root"* ]]

    # Nothing was touched
    [ -f "${MARKERLESS}/important~" ]
}

@test "repo-clean.sh honours an explicit --root" {
    printf 'junk\n' >"${PROJECT_DIR}/junk~"

    # Point at the git-marked project from an unrelated location
    run bash "$CLEAN" --root "$PROJECT_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 removed, 0 failed"* ]]

    [ ! -e "${PROJECT_DIR}/junk~" ]
}

@test "repo-clean.sh --root still refuses a directory with no project marker" {
    make_markerless_copy
    printf 'keep\n' >"${MARKERLESS}/important~"

    # An explicit path does not grant permission to nuke an arbitrary tree.
    run bash "$CLEAN" --root "$MARKERLESS"

    [ "$status" -ne 0 ]
    [ -f "${MARKERLESS}/important~" ]
}

@test "repo-clean.sh documents --root in its help text" {
    run bash "$CLEAN" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--root"* ]]
}