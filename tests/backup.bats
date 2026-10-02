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
# --- FIX 3: ENABLE_BACKUP is honoured (M10) ------------------------------

@test "backup.sh skips cleanly when ENABLE_BACKUP=false" {
    run env ENABLE_BACKUP=false BACKUP_DIR="$BACKUP_DIR" \
        BACKUP_SOURCES=".zshrc" bash "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"disabled"* ]]

    # nothing was written
    [ -z "$(find "$BACKUP_DIR" -name '.zshrc_*')" ]
}

@test "backup.sh runs when ENABLE_BACKUP is not set" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc" \
        bash "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -eq 0 ]
    [ -n "$(find "$BACKUP_DIR" -name '.zshrc_*')" ]
}

@test "default.conf declares ENABLE_BACKUP and ENABLE_CLEANUP" {
    run grep -q '^ENABLE_BACKUP=' "${PROJECT_ROOT}/config/default.conf"
    [ "$status" -eq 0 ]
    run grep -q '^ENABLE_CLEANUP=' "${PROJECT_ROOT}/config/default.conf"
    [ "$status" -eq 0 ]
}

# --- FIX 4 (M16): a missing source fails clearly, others still back up --

@test "backup.sh fails clearly for a source that does not exist" {
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES=".zshrc .does-not-exist" \
        bash "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Source file not found"* ]]
    [[ "$output" == *"does-not-exist"* ]]
    [[ "$output" != *"Backup completed successfully"* ]]

    # the source that DID exist was still backed up
    [ -n "$(find "$BACKUP_DIR" -name '.zshrc_*')" ]
    [ -z "$(find "$BACKUP_DIR" -name '.does-not-exist_*')" ]
}

# --- FIX 1 (L13): sources sharing a basename must not collide -------------

@test "two sources with the same basename get distinct backups" {
    mkdir -p "$HOME/.ssh"
    printf 'TOPLEVEL\n' >"$HOME/config"
    printf 'SSHCONF\n' >"$HOME/.ssh/config"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES="config .ssh/config" \
        bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    # two distinct backup files, not one overwritten. The run's manifest is
    # not itself a backup, so it is excluded from the count.
    local count
    count="$(find "$BACKUP_DIR" -type f ! -name 'manifest_*.json' | wc -l | tr -d ' ')"
    [ "$count" -eq 2 ]

    # and both original contents are recoverable from separate backups
    run grep -rl 'TOPLEVEL' "$BACKUP_DIR"
    [ "$status" -eq 0 ]
    run grep -rl 'SSHCONF' "$BACKUP_DIR"
    [ "$status" -eq 0 ]
}

@test "each colliding source restores its own content independently" {
    mkdir -p "$HOME/.ssh"
    printf 'TOPLEVEL\n' >"$HOME/config"
    printf 'SSHCONF\n' >"$HOME/.ssh/config"

    env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES="config .ssh/config" \
        bash "${SCRIPTS_DIR}/backup.sh"

    # clobber both live files
    printf 'CLOBBERED\n' >"$HOME/config"
    printf 'CLOBBERED\n' >"$HOME/.ssh/config"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES="config .ssh/config" \
        bash "${SCRIPTS_DIR}/restore.sh"
    [ "$status" -eq 0 ]

    run cat "$HOME/config"
    [[ "$output" == *"TOPLEVEL"* ]]

    run cat "$HOME/.ssh/config"
    [[ "$output" == *"SSHCONF"* ]]
}

# --- FIX 2 (L12): paths containing spaces --------------------------------

@test "newline-separated sources support a path containing a space" {
    printf 'spaced\n' >"$HOME/my config"
    local newline_sources
    newline_sources="$(printf '.zshrc\nmy config')"

    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES="$newline_sources" \
        bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    # the space-containing file was actually backed up
    run grep -rl 'spaced' "$BACKUP_DIR"
    [ "$status" -eq 0 ]
}

@test "backup warns when a token looks like a split space-containing path" {
    printf 'spaced\n' >"$HOME/my config"

    # space-separated listing of a path that contains a space
    run env BACKUP_DIR="$BACKUP_DIR" BACKUP_SOURCES="my config" \
        bash "${SCRIPTS_DIR}/backup.sh"

    [[ "$output" == *"space"* ]]
    [[ "$output" == *"my config"* ]]
}

@test "default.conf documents the newline alternative" {
    run grep -qi 'newline' "${PROJECT_ROOT}/config/default.conf"
    [ "$status" -eq 0 ]
}

# --- FIX 3 (L9): backups are never briefly world-readable ----------------

@test "backup creates the file with restrictive mode, not copy-then-chmod" {
    local stub="${BATS_TEST_TMPDIR}/copystub"
    mkdir -p "$stub"
    : >"$stub/calls.log"
    for tool in install cp chmod; do
        printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nexec /usr/bin/%s "$@"\n' \
            "$tool" "$stub/calls.log" "$tool" >"${stub}/$tool"
        chmod +x "${stub}/$tool"
    done

    # A world-readable source is exactly the risky case
    printf 'not-a-secret-but-644\n' >"$HOME/wide-open"
    chmod 644 "$HOME/wide-open"

    run env PATH="${stub}:${PATH}" BACKUP_DIR="$BACKUP_DIR" \
        BACKUP_SOURCES="wide-open" bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    # restrictive mode applied as part of creating the file
    run grep -q 'install -m 600' "$stub/calls.log"
    [ "$status" -eq 0 ]

    # no copy-preserving-source-mode step onto the destination
    run grep -q 'cp -p' "$stub/calls.log"
    [ "$status" -ne 0 ]

    # and the end state is still 600
    local perms
    if stat -f "%A" "$HOME/wide-open" >/dev/null 2>&1; then
        perms="$(stat -f "%A" "${BACKUP_DIR}"/*wide-open* 2>/dev/null)"
    else
        perms="$(stat -c "%a" "${BACKUP_DIR}"/*wide-open* 2>/dev/null)"
    fi
    [ "$perms" = "600" ]
}

# --- FIX 1: run manifest (M19) -----------------------------------------
# A backup that cannot be proven intact is not much of a backup. Each run
# records what it wrote and the SHA-256 of what it wrote, so restore.sh can
# tell a good backup from a corrupted one.

@test "backup.sh writes a manifest after a successful run" {
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    run bash -c 'ls "$1"/manifest_*.json 2>/dev/null' _ "$BACKUP_DIR"
    [ "$status" -eq 0 ]
}

@test "manifest records backup filename, source path, sha256 and timestamp" {
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    local manifest
    manifest="$(ls "$BACKUP_DIR"/manifest_*.json | head -n1)"

    run cat "$manifest"
    # backup filename, source path and a full SHA-256
    [[ "$output" == *'"backup":'* ]]
    [[ "$output" == *'"source":'* ]]
    [[ "$output" == *'"sha256":'* ]]
    [[ "$output" =~ [0-9a-f]{64} ]]
    # and the run timestamp
    [[ "$output" == *'"timestamp":'* ]]
}

@test "manifest lists every source backed up in the run" {
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    local manifest
    manifest="$(ls "$BACKUP_DIR"/manifest_*.json | head -n1)"
    run cat "$manifest"

    [[ "$output" == *"${HOME}/.zshrc"* ]]
    [[ "$output" == *"${HOME}/.gitconfig"* ]]
    [[ "$output" == *"${HOME}/.ssh/config"* ]]
}

@test "manifest sha256 matches the real content of each backup file" {
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    local manifest backup expected actual
    manifest="$(ls "$BACKUP_DIR"/manifest_*.json | head -n1)"
    # backup_key() keeps .zshrc as ".zshrc"; only slashes become %
    backup="$(ls "$BACKUP_DIR"/.zshrc_* | head -n1)"

    expected="$(grep -F "\"backup\":\"$(basename "$backup")\"" "$manifest" |
        sed -n 's/.*"sha256":"\([0-9a-f]*\)".*/\1/p')"
    actual="$(shasum -a 256 "$backup" | awk '{print $1}')"

    [ -n "$expected" ]
    [ "$expected" = "$actual" ]
}

@test "backup.sh writes no manifest when a source is missing" {
    # First prove the mechanism works at all, otherwise "no manifest" would
    # also be true simply because no manifest is ever written.
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]
    run bash -c 'ls "$1"/manifest_*.json >/dev/null 2>&1' _ "$BACKUP_DIR"
    [ "$status" -eq 0 ]

    # Now a run that fails partway must leave no new manifest asserting
    # success for files it never reached.
    rm -f "$BACKUP_DIR"/manifest_*.json
    export BACKUP_SOURCES="${HOME}/.zshrc ${HOME}/does-not-exist"

    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -ne 0 ]

    run bash -c 'ls "$1"/manifest_*.json 2>/dev/null' _ "$BACKUP_DIR"
    [ "$status" -ne 0 ]
}

@test "manifest is not world-readable" {
    run bash "${SCRIPTS_DIR}/backup.sh"
    [ "$status" -eq 0 ]

    local manifest mode
    manifest="$(ls "$BACKUP_DIR"/manifest_*.json | head -n1)"
    mode="$(stat -f '%Lp' "$manifest" 2>/dev/null || stat -c '%a' "$manifest")"

    # owner-only: the manifest names the user's real dotfile paths
    [[ "${mode: -1}" != "7" ]]
    [[ "${mode: -1}" != "6" ]]
    [[ "${mode: -1}" != "5" ]]
    [[ "${mode: -1}" != "4" ]]
}
