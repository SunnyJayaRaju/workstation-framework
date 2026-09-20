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