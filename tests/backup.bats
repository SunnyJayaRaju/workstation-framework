#!/usr/bin/env bats

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export BACKUP_DIR="$BATS_TEST_TMPDIR/backups"

    mkdir -p "$HOME"
    mkdir -p "$BACKUP_DIR"

    printf '# test zshrc\n' >"$HOME/.zshrc"
}

teardown() {
    rm -rf "$HOME"
    rm -rf "$BACKUP_DIR"
}

@test "backup.sh executes successfully" {
    run env BACKUP_DIR="$BACKUP_DIR" ./scripts/backup.sh

    [ "$status" -eq 0 ]
}

@test "backup.sh creates a backup file" {
    run env BACKUP_DIR="$BACKUP_DIR" ./scripts/backup.sh

    [ "$status" -eq 0 ]

    run find "$BACKUP_DIR" -name 'zshrc_*'

    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "backup.sh prints completion message" {
    run env BACKUP_DIR="$BACKUP_DIR" ./scripts/backup.sh

    [[ "$output" == *"Backup completed successfully."* ]]
}