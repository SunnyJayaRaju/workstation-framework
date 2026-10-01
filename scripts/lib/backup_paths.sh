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
