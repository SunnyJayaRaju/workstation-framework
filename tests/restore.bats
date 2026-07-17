#!/usr/bin/env bats

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export BACKUP_DIR="$BATS_TEST_TMPDIR/backups"

    mkdir -p "$HOME"
    mkdir -p "$BACKUP_DIR"

    printf '# original\n' >"$HOME/.zshrc"

    printf '# restored\n' \
        >"$BACKUP_DIR/zshrc_2026-01-01_00-00-00"
}

teardown() {
    rm -rf "$HOME"
    rm -rf "$BACKUP_DIR"
}

@test "restore.sh executes successfully" {
    run env BACKUP_DIR="$BACKUP_DIR" ./scripts/restore.sh

    [ "$status" -eq 0 ]
}

@test "restore.sh restores latest backup" {
    run env BACKUP_DIR="$BACKUP_DIR" ./scripts/restore.sh

    [ "$status" -eq 0 ]

    run cat "$HOME/.zshrc"

    [ "$status" -eq 0 ]
    [[ "$output" == *"# restored"* ]]
}

@test "restore.sh prints completion message" {
    run env BACKUP_DIR="$BACKUP_DIR" ./scripts/restore.sh

    [[ "$output" == *"Restore completed successfully."* ]]
}