#!/usr/bin/env bats

load test_helper

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export BACKUP_DIR="$BATS_TEST_TMPDIR/backups"

    mkdir -p "$HOME"
    mkdir -p "$BACKUP_DIR"

    printf '# test zshrc\n' >"$HOME/.zshrc"
    printf '# test gitconfig\n' >"$HOME/.gitconfig"
    mkdir -p "$HOME/.ssh"
    printf 'Host *\n' >"$HOME/.ssh/config"
}

teardown() {
    rm -rf "$HOME"
    rm -rf "$BACKUP_DIR"
}

@test "backup.sh executes successfully" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .gitconfig" bash "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -eq 0 ]
}

@test "backup.sh creates backup files for all sources" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .gitconfig" bash "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -eq 0 ]

    run find "$BACKUP_DIR" -name '.zshrc_*'
    [ "$status" -eq 0 ]
    [ -n "$output" ]

    run find "$BACKUP_DIR" -name '.gitconfig_*'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "backup.sh prints completion message" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" bash "${SCRIPTS_DIR}/backup.sh"

    [[ "$output" == *"Backup completed successfully."* ]]
}

@test "backup.sh creates backup files with mode 600" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" bash "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -eq 0 ]

    local backup_file
    backup_file=$(find "$BACKUP_DIR" -name '.zshrc_*' | head -1)
    [ -n "$backup_file" ]
    [ -f "$backup_file" ]

    # Check file permissions are 600 (owner read/write only) - cross-platform stat
    local perms
    if stat -f "%A" "$backup_file" >/dev/null 2>&1; then
        perms=$(stat -f "%A" "$backup_file")   # BSD/macOS
    else
        perms=$(stat -c "%a" "$backup_file")   # GNU/Linux
    fi
    [ "$perms" = "600" ]
}

@test "installed backup.sh works from installed location" {
    # Install to a temp directory
    local install_dir="$BATS_TEST_TMPDIR/install"
    local test_home="$BATS_TEST_TMPDIR/test_home"
    local backup_dir="$test_home/.workstation/backups"

    mkdir -p "$install_dir"
    mkdir -p "$test_home/.ssh"

    printf '# test zshrc\n' >"$test_home/.zshrc"
    printf '# test gitconfig\n' >"$test_home/.gitconfig"
    printf 'Host *\n' >"$test_home/.ssh/config"

    # Install the framework
    export INSTALL_DIR="$install_dir"
    run bash "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]

    # Run the INSTALLED backup.sh
    export HOME="$test_home"
    unset BACKUP_DIR
    run bash "$install_dir/backup.sh"
    [ "$status" -eq 0 ]

    # Verify backup was created with mode 600
    local backup_file
    backup_file=$(find "$backup_dir" -name '.zshrc_*' | head -1)
    [ -n "$backup_file" ]
    [ -f "$backup_file" ]

    local perms
    if stat -f "%A" "$backup_file" >/dev/null 2>&1; then
        perms=$(stat -f "%A" "$backup_file")   # BSD/macOS
    else
        perms=$(stat -c "%a" "$backup_file")   # GNU/Linux
    fi
    [ "$perms" = "600" ]

    # Verify content was backed up correctly
    run cat "$backup_file"
    [ "$status" -eq 0 ]
    [[ "$output" == "# test zshrc" ]]
}