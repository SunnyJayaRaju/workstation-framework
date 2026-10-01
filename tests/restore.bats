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
    # ~/.ssh/config is stored under its basename, i.e. "config_<timestamp>"
    printf '# restored ssh config\n' >"$BACKUP_DIR/config_2026-01-01_00-00-00"
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

@test "restore.sh preserves the file it overwrites" {
    local before
    before="$(cat "$HOME/.zshrc")"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" bash "${SCRIPTS_DIR}/restore.sh"
    [ "$status" -eq 0 ]

    # The live file now holds the backup...
    run cat "$HOME/.zshrc"
    [[ "$output" == *"# restored zshrc"* ]]

    # ...and a safety copy of the pre-restore content exists beside it
    local safety
    safety="$(find "$HOME" -maxdepth 1 -name '.zshrc.restore-safety-*' | head -n1)"
    [ -n "$safety" ]

    run cat "$safety"
    [ "$status" -eq 0 ]
    [ "$output" = "$before" ]
}

@test "restore.sh creates a missing destination directory" {
    rm -rf "$HOME/.ssh"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".ssh/config" bash "${SCRIPTS_DIR}/restore.sh"
    [ "$status" -eq 0 ]

    [ -d "$HOME/.ssh" ]
    run cat "$HOME/.ssh/config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"# restored ssh config"* ]]
}

@test "restore.sh --dry-run modifies nothing" {
    local before
    before="$(cat "$HOME/.zshrc")"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" bash \
        "${SCRIPTS_DIR}/restore.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would restore"* ]]

    # Live file unchanged and no safety copy created
    run cat "$HOME/.zshrc"
    [ "$output" = "$before" ]
    [ -z "$(find "$HOME" -maxdepth 1 -name '.zshrc.restore-safety-*')" ]
}

@test "restore.sh --dry-run creates no missing destination directory" {
    rm -rf "$HOME/.ssh"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".ssh/config" bash \
        "${SCRIPTS_DIR}/restore.sh" --dry-run
    [ "$status" -eq 0 ]

    [ ! -d "$HOME/.ssh" ]
}

@test "restore.sh refuses to write a safety copy through a symlink" {
    local target="${BATS_TEST_TMPDIR}/symlink-target"
    printf 'do-not-overwrite\n' >"$target"

    # The safety-copy name embeds the second it was created, which restore.sh
    # computes internally. So plant the symlink for the current second and
    # run immediately, retrying until the guard trips. Portable: no BSD-only
    # `date -v`, unlike a computed future timestamp.
    local ts rc=0
    for _ in 1 2 3 4 5; do
        ts="$(date +%Y%m%d%H%M%S)"
        ln -sf "$target" "${HOME}/.zshrc.restore-safety-${ts}"

        run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" bash \
            "${SCRIPTS_DIR}/restore.sh"
        rc="$status"
        [ "$rc" -ne 0 ] && break
    done

    # Fail closed: restore refused rather than writing through the symlink
    [ "$rc" -ne 0 ]

    run cat "$target"
    [ "$status" -eq 0 ]
    [ "$output" = "do-not-overwrite" ]
}

@test "restore.sh documents that safety copies are never pruned" {
    run bash "${SCRIPTS_DIR}/restore.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"never"* ]]
    [[ "$output" == *"safety"* ]]
}
# --- FIX 4 (M16): failure-path coverage ---------------------------------

@test "restore.sh fails clearly when no backup exists for a source" {
    # Nothing in BACKUP_DIR matches this source
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".no-such-file" bash \
        "${SCRIPTS_DIR}/restore.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"No backup found"* ]]
    [[ "$output" == *"no-such-file"* ]]
    [[ "$output" != *"Restore completed successfully"* ]]

    # and nothing was created for it
    [ ! -e "$HOME/.no-such-file" ]
}

@test "restore.sh restores the available source when another has no backup" {
    # .zshrc has a backup (from setup); .missing does not.
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .missing" bash \
        "${SCRIPTS_DIR}/restore.sh"

    # overall non-zero because of the partial failure
    [ "$status" -ne 0 ]

    # Assert on the restore output BEFORE any further `run` clobbers $output.
    [[ "$output" == *"No backup found"* ]]
    [[ "$output" == *"missing"* ]]
    [[ "$output" != *"Restore completed successfully"* ]]

    # the one that could be restored WAS restored
    run cat "$HOME/.zshrc"
    [[ "$output" == *"# restored zshrc"* ]]
}
