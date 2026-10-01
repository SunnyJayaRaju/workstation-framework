#!/usr/bin/env bats

load test_helper

setup() {
    export INSTALL_DIR="$BATS_TEST_TMPDIR/install"
    mkdir -p "$INSTALL_DIR"
}

teardown() {
    rm -rf "$INSTALL_DIR"
}

@test "install.sh executes successfully" {
    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh"

    [ "$status" -eq 0 ]
}

@test "install.sh prints completion message" {
    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh"

    [[ "$output" == *"Installation completed successfully."* ]]
}

@test "install.sh exits non-zero when INSTALL_DIR is not a directory" {
    # Create a temp file to use as INSTALL_DIR (not a directory)
    local bad_install_dir
    bad_install_dir="$(mktemp)"
    
    # Run install.sh with INSTALL_DIR pointing to a file (not writable as dir)
    run env INSTALL_DIR="$bad_install_dir" bash "${SCRIPTS_DIR}/install.sh"
    
    [ "$status" -ne 0 ]
    [[ "$output" == *"File exists"* ]] || [[ "$output" == *"Failed to install"* ]] || [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"FAIL"* ]]
    
    rm -f "$bad_install_dir"
}
# --- FIX 2: a reinstall prunes lib files that no longer exist in source --

@test "install.sh prunes stale files from the installed lib" {
    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    # A leftover from a previous version
    printf '#!/usr/bin/env bash\n' >"${INSTALL_DIR}/lib/removed-in-this-version.sh"
    # Something the user put there themselves, which must survive
    printf 'mine\n' >"${INSTALL_DIR}/user-placed-file.txt"

    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    # stale lib file pruned
    [ ! -e "${INSTALL_DIR}/lib/removed-in-this-version.sh" ]

    # real lib files untouched
    [ -f "${INSTALL_DIR}/lib/logging.sh" ]
    [ -f "${INSTALL_DIR}/lib/errors.sh" ]

    # the prune is scoped to lib/: anything the user placed elsewhere survives
    [ -f "${INSTALL_DIR}/user-placed-file.txt" ]
    [ -f "${INSTALL_DIR}/backup.sh" ]
}

@test "install.sh prune never touches anything outside INSTALL_DIR/lib" {
    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    # a sibling of INSTALL_DIR that must be left completely alone
    local sibling="${BATS_TEST_TMPDIR}/sibling-config"
    mkdir -p "$sibling"
    printf 'keep\n' >"${sibling}/VERSION"
    printf 'keep\n' >"${sibling}/default.conf"

    printf '# stale\n' >"${INSTALL_DIR}/lib/stale.sh"
    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    [ -f "${sibling}/VERSION" ]
    [ -f "${sibling}/default.conf" ]
}

# --- FIX 4 (M16): install must not claim success when it fails -----------

@test "install.sh reports failure clearly instead of claiming success" {
    # A read-only INSTALL_DIR: it exists, so ensure_directory succeeds, but
    # the copy cannot proceed.
    local readonly_dir="${BATS_TEST_TMPDIR}/readonly-install"
    mkdir -p "$readonly_dir"
    chmod 555 "$readonly_dir"

    run env INSTALL_DIR="$readonly_dir" bash "${SCRIPTS_DIR}/install.sh"

    chmod 755 "$readonly_dir"

    # EX_CANTCREAT (73), not a bare `exit EX_CANTCREAT` shell error
    [ "$status" -eq 73 ]
    [[ "$output" == *"Cannot create"* ]]
    [[ "$output" != *"Installation completed successfully"* ]]
    [[ "$output" != *"numeric argument required"* ]]
}

@test "install.sh reports usage errors with EX_USAGE, not a shell error" {
    run env INSTALL_DIR="$INSTALL_DIR" bash "${SCRIPTS_DIR}/install.sh" --nope
    [ "$status" -eq 64 ]
    [[ "$output" == *"Unknown option"* ]]
    [[ "$output" != *"numeric argument required"* ]]
}

# --- FIX 5: .install_dir round-trip (M17) ------------------------------
# install.sh writes .install_dir and uninstall.sh reads it to decide what to
# delete. Nothing tested the two together, so a change to either could silently
# break the marker contract.

@test "install.sh records INSTALL_DIR in .install_dir" {
    run bash "${SCRIPTS_DIR}/install.sh"

    [ "$status" -eq 0 ]
    [ -f "${INSTALL_DIR}/.install_dir" ]
    [ "$(cat "${INSTALL_DIR}/.install_dir")" = "$INSTALL_DIR" ]
}

@test ".install_dir round-trips: uninstall.sh finds and removes what install.sh wrote" {
    run bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -f "${INSTALL_DIR}/.install_dir" ]

    # uninstall.sh must actually READ the marker, not just skip it
    run --separate-stderr bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Install marker removed"* ]]
    [ ! -f "${INSTALL_DIR}/.install_dir" ]
}

@test ".install_dir holds a single path and no extra content" {
    run bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    # exactly one line, and it is the install dir
    [ "$(wc -l <"${INSTALL_DIR}/.install_dir" | tr -d ' ')" = "1" ]
    [ "$(cat "${INSTALL_DIR}/.install_dir")" = "$INSTALL_DIR" ]
}

@test "install.sh overwrites a stale .install_dir left by an earlier install" {
    printf '%s\n' "/some/old/path" >"${INSTALL_DIR}/.install_dir"

    run bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    [ "$(cat "${INSTALL_DIR}/.install_dir")" = "$INSTALL_DIR" ]
}

@test "uninstall.sh removes .install_dir when it cleans up" {
    run bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -f "${INSTALL_DIR}/.install_dir" ]

    run bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]

    [ ! -f "${INSTALL_DIR}/.install_dir" ]
}
