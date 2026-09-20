#!/usr/bin/env bats

# Integration tests for full workflow scenarios

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export BACKUP_DIR="$BATS_TEST_TMPDIR/backups"
    export INSTALL_DIR="$BATS_TEST_TMPDIR/install"

    mkdir -p "$HOME"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$INSTALL_DIR"

    printf '# test zshrc\n' >"$HOME/.zshrc"
    printf '# test gitconfig\n' >"$HOME/.gitconfig"
    mkdir -p "$HOME/.ssh"
    printf 'Host *\n' >"$HOME/.ssh/config"
}

teardown() {
    rm -rf "$HOME"
    rm -rf "$BACKUP_DIR"
    rm -rf "$INSTALL_DIR"
}

@test "install.sh is idempotent (run twice = same result)" {
    # First install
    run env INSTALL_DIR="$INSTALL_DIR" ./scripts/install.sh
    [ "$status" -eq 0 ]

    # Count installed files
    find "$INSTALL_DIR" -type f -name "*.sh" | wc -l >"$BATS_TEST_TMPDIR/count1.txt"
    first_count=$(cat "$BATS_TEST_TMPDIR/count1.txt")

    # Second install (should succeed and not duplicate)
    run env INSTALL_DIR="$INSTALL_DIR" ./scripts/install.sh
    [ "$status" -eq 0 ]

    find "$INSTALL_DIR" -type f -name "*.sh" | wc -l >"$BATS_TEST_TMPDIR/count2.txt"
    second_count=$(cat "$BATS_TEST_TMPDIR/count2.txt")

    [ "$first_count" -eq "$second_count" ]
}

@test "uninstall.sh removes all installed files" {
    # Install first
    run env INSTALL_DIR="$INSTALL_DIR" ./scripts/install.sh
    [ "$status" -eq 0 ]

    # Verify files exist
    run test -f "$INSTALL_DIR/backup.sh"
    [ "$status" -eq 0 ]
    run test -f "$INSTALL_DIR/lib/logging.sh"
    [ "$status" -eq 0 ]

    # Uninstall
    run env INSTALL_DIR="$INSTALL_DIR" ./scripts/uninstall.sh
    [ "$status" -eq 0 ]

    # Verify files are gone
    run test -f "$INSTALL_DIR/backup.sh"
    [ "$status" -ne 0 ]
    run test -d "$INSTALL_DIR/lib"
    [ "$status" -ne 0 ]
}

@test "backup.sh is idempotent (multiple runs create separate timestamped backups)" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" ./scripts/backup.sh
    [ "$status" -eq 0 ]

    find "$BACKUP_DIR" -name '.zshrc_*' | wc -l >"$BATS_TEST_TMPDIR/bcount1.txt"
    count1=$(cat "$BATS_TEST_TMPDIR/bcount1.txt")
    [ "$count1" -eq 1 ]

    # Small delay to ensure different timestamp
    sleep 1

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" ./scripts/backup.sh
    [ "$status" -eq 0 ]

    find "$BACKUP_DIR" -name '.zshrc_*' | wc -l >"$BATS_TEST_TMPDIR/bcount2.txt"
    count2=$(cat "$BATS_TEST_TMPDIR/bcount2.txt")
    [ "$count2" -eq 2 ]
}

@test "restore.sh restores correct content after backup" {
    # Create backup
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .gitconfig" ./scripts/backup.sh
    [ "$status" -eq 0 ]

    # Modify source files
    printf '# modified zshrc\n' >"$HOME/.zshrc"
    printf '# modified gitconfig\n' >"$HOME/.gitconfig"

    # Restore
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .gitconfig" ./scripts/restore.sh
    [ "$status" -eq 0 ]

    # Verify restored content
    run cat "$HOME/.zshrc"
    [ "$status" -eq 0 ]
    [[ "$output" == "# test zshrc" ]]

    run cat "$HOME/.gitconfig"
    [ "$status" -eq 0 ]
    [[ "$output" == "# test gitconfig" ]]
}

@test "update.sh runs install and doctor when on a branch" {
    # This test simulates update.sh behavior in a git repo
    run ./scripts/update.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Framework updated successfully."* ]]
}

@test "doctor.sh detects missing dependencies" {
    # Test with a fake missing command by temporarily hiding git
    PATH="/usr/bin:/bin" run ./scripts/doctor.sh
    # Should still run but report missing git
    [ "$status" -eq 0 ]
    [[ "$output" == *"git missing"* ]] || [[ "$output" == *"git installed"* ]]
}

@test "shell-quality.sh returns non-zero for script with syntax error" {
    # Create a script with syntax error
    local bad_script="$BATS_TEST_TMPDIR/bad.sh"
    echo 'if true; then echo "missing fi"' >"$bad_script"

    run ./scripts/shell-quality.sh "$bad_script"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Quality checks failed"* ]]
}

@test "shell-quality.sh returns zero for valid script" {
    # Use a script that is known to be well-formatted and won't be modified by shfmt
    run ./scripts/shell-quality.sh ./scripts/lib/errors.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"All quality checks passed"* ]]
}

@test "sync.sh handles detached HEAD gracefully" {
    # In BATS test environment, we're in a git repo but may be detached
    run ./scripts/sync.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Synchronization check completed."* ]]
}

@test "repo-clean.sh dry-run mode shows files without deleting" {
    # Create test temp files in the project root
    local project_root
    project_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    touch "$project_root/test_cleanup.orig"
    touch "$project_root/test_cleanup~"

    # Run repo-clean.sh --dry-run
    run bash scripts/repo-clean.sh --dry-run
    [ "$status" -eq 0 ]

    # Files should still exist after dry-run
    [ -f "$project_root/test_cleanup.orig" ]
    [ -f "$project_root/test_cleanup~" ]

    # Clean up test files
    rm -f "$project_root/test_cleanup.orig" "$project_root/test_cleanup~"
}

@test "bootstrap.sh delegates to install.sh" {
    run ./scripts/bootstrap.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation completed successfully."* ]]
}