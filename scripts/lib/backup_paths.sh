#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Library: backup_paths.sh
# Version: see VERSION file
#
# Purpose:
#   Shared path handling for backup.sh and restore.sh.
#
#   These two scripts MUST agree on how a source path maps to a backup
#   filename. They previously each carried their own copy of this logic and
#   drifted, so a file backed up by one could not be found by the other.
###############################################################################

# Parse BACKUP_SOURCES into the BACKUP_SOURCES array.
#
# Two accepted formats:
#   - space-separated (single line): the original format, for paths that do
#     not contain a space
#   - one path per line (newline-separated): required for paths containing
#     a space, e.g. "my notes.txt"
parse_backup_sources() {
    local value="${BACKUP_SOURCES:-${HOME}/.zshrc ${HOME}/.gitconfig ${HOME}/.ssh/config}"

    if [[ "$value" == *$'\n'* ]]; then
        # A while-read loop, not mapfile: mapfile is Bash 4+ and this project
        # supports Bash 3.2 (macOS default). See CODE_REVIEW_CHECKLIST.md.
        BACKUP_SOURCES=()
        local line=""
        while IFS= read -r line; do
            BACKUP_SOURCES+=("$line")
        done <<<"$value"
    else
        IFS=' ' read -r -a BACKUP_SOURCES <<<"$value"
    fi
}

# Expand a configured source to an absolute path.
expand_source_path() {
    local source="$1"

    if [[ "$source" != /* ]]; then
        source="${HOME}/${source}"
    fi
    source="${source/#\~/$HOME}"
    printf '%s' "$source"
}

# A collision-free backup filename stem for a source.
#
# Keying on basename alone made ~/.ssh/config and a top-level ~/config share
# one backup file, silently overwriting each other's history. The path
# relative to $HOME (with "/" replaced by "%") distinguishes them while
# staying machine-independent.
backup_key() {
    local source="$1"
    local key

    if [[ "$source" == "$HOME"/* ]]; then
        key="${source#"$HOME"/}"
    else
        key="${source#/}"
    fi

    printf '%s' "${key//\//%}"
}

# SHA-256 of a file's content, printed lowercase hex.
#
# Which tool provides it differs by platform: macOS ships shasum but not
# sha256sum, most Linux images ship sha256sum and often shasum, and openssl
# is a third fallback. Probed in that order rather than assumed.
sha256_of() {
    local file="$1"

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $NF}'
    else
        return 1
    fi
}

# JSON-escape a string for use as a quoted JSON value.
# Only the two characters JSON itself reserves inside a string, plus control
# characters, which cannot appear in a filename we are willing to back up.
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# The manifest covering a given backup file, if any.
#
# One manifest per run, named for that run's timestamp, and every backup in a
# run carries the same timestamp suffix. Returns 1 when no manifest exists,
# which is the normal case for any backup taken before manifests did.
manifest_for_backup() {
    local backup="$1"
    local backup_dir
    backup_dir="$(dirname "$backup")"
    local base
    base="$(basename "$backup")"

    # Extract the run timestamp from the trailing YYYY-MM-DD_HH-MM-SS.
    #
    # Not by stripping up to the last underscore: the timestamp itself contains
    # underscores, so `${base##*_}` yields "06-49-46" and the lookup silently
    # misses, turning every backup into a false "legacy" one. Match the fixed
    # timestamp shape instead, which is unambiguous whatever the key contains.
    local ts
    ts="$(printf '%s' "$base" |
        sed -n 's/.*_\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}\)$/\1/p')"

    [[ -n "$ts" ]] || return 1

    local candidate="${backup_dir}/manifest_${ts}.json"
    [[ -f "$candidate" ]] || return 1
    printf '%s' "$candidate"
}

# The SHA-256 a manifest records for a given backup filename.
#
# Reads the manifest as text and never evaluates it: a manifest is a file in
# the backup store and is therefore untrusted input. Note this returns only a
# hash to compare against -- it never yields a destination path, so a
# tampered manifest can cause a refusal but cannot redirect a write.
manifest_hash_for() {
    local manifest="$1"
    local backup_name="$2"

    local line
    line="$(grep -F "\"backup\":\"$(json_escape "$backup_name")\"" "$manifest" 2>/dev/null |
        head -n1)" || true

    [[ -n "$line" ]] || return 1
    # only accept a full 64-char lowercase hex digest
    printf '%s' "$line" | sed -n 's/.*"sha256":"\([0-9a-f]\{64\}\)".*/\1/p'
}
