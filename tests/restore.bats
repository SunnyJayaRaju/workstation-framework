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

# --- FIX 2: verify before overwrite (M20) ------------------------------
# restore.sh overwrites the user's live dotfiles. Doing that from a backup
# that has been corrupted, truncated or tampered with since it was taken
# would replace good content with bad and say nothing.

# Replace the legacy fixtures with real backup.sh output, which writes a
# manifest alongside the run.
manifest_backups() {
    # `rm -f "$BACKUP_DIR"/*` would NOT remove these: every backup of a
    # dotfile source is itself a dotfile. Leaving the setup() fixtures in
    # place meant the glob below matched a stale backup instead of the new one.
    find "$BACKUP_DIR" -mindepth 1 -delete
    export BACKUP_SOURCES="${HOME}/.zshrc ${HOME}/.gitconfig"
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]
}

# Flip one byte of a backup, leaving its length unchanged. Uses plain shell
# string substitution rather than dd, which is unavailable on this machine.
corrupt_one_byte() {
    local file="$1"
    local content
    content="$(cat "$file")"
    printf '%s' "${content/#\#/X}" >"$file"

    # prove the content really changed, so this cannot silently no-op
    [ "$content" != "$(cat "$file")" ]
}

@test "restore restores cleanly when the manifest verifies" {
    manifest_backups
    # there really is a manifest, so "silent" below can only mean verified,
    # not "nothing to check"
    run bash -c 'ls "$1"/manifest_*.json >/dev/null 2>&1' _ "$BACKUP_DIR"
    [ "$status" -eq 0 ]

    printf '# tampered\n' >"$HOME/.zshrc"

    run bash "${SCRIPTS_DIR}/restore.sh"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.zshrc")" = "# original zshrc" ]
    # a verified restore is silent about integrity
    [[ "$output" != *"ntegrity"* ]]
}

@test "restore refuses a corrupted backup and leaves the source untouched" {
    manifest_backups
    corrupt_one_byte "$(ls -t "$BACKUP_DIR"/.zshrc_* | head -n1)"
    printf '# tampered\n' >"$HOME/.zshrc"

    run bash "${SCRIPTS_DIR}/restore.sh"

    [ "$status" -ne 0 ]
    # names the failure and the file
    [[ "$output" == *"ntegrity"* ]]
    [[ "$output" == *"zshrc"* ]]
    # and crucially, the live file was not overwritten with bad content
    [ "$(cat "$HOME/.zshrc")" = "# tampered" ]
}

@test "a corrupted backup does not stop the other sources restoring" {
    manifest_backups
    corrupt_one_byte "$(ls -t "$BACKUP_DIR"/.zshrc_* | head -n1)"
    printf '# tampered\n' >"$HOME/.zshrc"
    printf '# tampered gitconfig\n' >"$HOME/.gitconfig"

    run bash "${SCRIPTS_DIR}/restore.sh"

    # the run reports failure overall...
    [ "$status" -ne 0 ]
    # ...but the intact source was still restored
    [ "$(cat "$HOME/.gitconfig")" = "# original gitconfig" ]
    [ "$(cat "$HOME/.zshrc")" = "# tampered" ]
}

@test "a legacy backup with no manifest still restores, with only a notice" {
    # the fixtures in setup() were written by hand: no manifest exists, which
    # is exactly the shape of every backup taken before this feature existed
    export BACKUP_SOURCES="${HOME}/.zshrc"

    run bash "${SCRIPTS_DIR}/restore.sh"

    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.zshrc")" = "# restored zshrc" ]
    # told it could not verify, but not failed
    [[ "$output" == *"manifest"* ]]
    [[ "$output" != *"ntegrity check failed"* ]]
}

@test "restore --dry-run reports an integrity failure without touching anything" {
    manifest_backups
    corrupt_one_byte "$(ls -t "$BACKUP_DIR"/.zshrc_* | head -n1)"
    printf '# tampered\n' >"$HOME/.zshrc"

    run bash "${SCRIPTS_DIR}/restore.sh" --dry-run

    [ "$status" -ne 0 ]
    [[ "$output" == *"ntegrity"* ]]
    [ "$(cat "$HOME/.zshrc")" = "# tampered" ]
}

@test "a tampered manifest cannot redirect a restore to another path" {
    # The manifest records a "source" field, but restore must never act on it:
    # the destination always comes from BACKUP_SOURCES. If it were trusted, a
    # manifest edited to name an arbitrary path would let a backup overwrite
    # that file.
    manifest_backups
    local manifest victim
    manifest="$(ls "$BACKUP_DIR"/manifest_*.json | head -n1)"
    victim="${BATS_TEST_TMPDIR}/must-not-be-written"
    printf 'do not touch\n' >"$victim"

    # repoint every recorded source at the unrelated file, hash left intact
    sed "s|\"source\":\"[^\"]*\"|\"source\":\"${victim}\"|" "$manifest" \
        >"${manifest}.new"
    mv -f "${manifest}.new" "$manifest"

    run bash "${SCRIPTS_DIR}/restore.sh"

    # the victim is untouched, and the real source came from BACKUP_SOURCES
    [ "$(cat "$victim")" = "do not touch" ]
    [ "$(cat "$HOME/.zshrc")" = "# original zshrc" ]
}
