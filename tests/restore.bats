#!/usr/bin/env bats

load test_helper

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export BACKUP_DIR="$BATS_TEST_TMPDIR/backups"

    mkdir -p "$HOME"
    mkdir -p "$BACKUP_DIR"

    printf '# original zshrc\n' >"$HOME/.zshrc"
    printf '# original gitconfig\n' >"$HOME/.gitconfig"
    mkdir -p "$HOME/.ssh"
    printf '# original ssh config\n' >"$HOME/.ssh/config"

    # Create backup files with timestamp pattern that restore.sh expects (basename with leading dot)
    printf '# restored zshrc\n' >"$BACKUP_DIR/.zshrc_2026-01-01_00-00-00"
    printf '# restored gitconfig\n' >"$BACKUP_DIR/.gitconfig_2026-01-01_00-00-00"
    mkdir -p "$BACKUP_DIR/.ssh"
    printf '# restored ssh config\n' >"$BACKUP_DIR/.ssh_config_2026-01-01_00-00-00"
}

teardown() {
    rm -rf "$HOME"
    rm -rf "$BACKUP_DIR"
}

@test "restore.sh executes successfully" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .gitconfig" bash "${SCRIPTS_DIR}/restore.sh"

    [ "$status" -eq 0 ]
}

@test "restore.sh restores latest backup for all sources" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .gitconfig" bash "${SCRIPTS_DIR}/restore.sh"

    [ "$status" -eq 0 ]

    run cat "$HOME/.zshrc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# restored zshrc"* ]]

    run cat "$HOME/.gitconfig"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# restored gitconfig"* ]]
}

@test "restore.sh prints completion message" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" bash "${SCRIPTS_DIR}/restore.sh"

    [[ "$output" == *"Restore completed successfully."* ]]
}