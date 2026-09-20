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