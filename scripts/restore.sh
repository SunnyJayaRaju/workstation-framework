#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: restore.sh
# Version: see VERSION file
#
# Purpose:
#   Restore the latest backups for configured configuration files.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

# shellcheck source=lib/errors.sh
source "${SCRIPT_DIR}/lib/errors.sh"

require_var BACKUP_DIR "$EX_CONFIG"

readonly BACKUP_DIR

# Configurable backup sources - must match backup.sh
# (parsed below, once the shared helper has been sourced)

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source=lib/backup_paths.sh
source "${SCRIPT_DIR}/lib/backup_paths.sh"

parse_backup_sources

DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Restore the latest backups for configured configuration files.

Options:
  -n, --dry-run    Show what would be restored without restoring
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Environment Variables:
  BACKUP_DIR       Backup source directory (required)
  BACKUP_SOURCES   Space-separated list of files to restore (default: .zshrc .gitconfig .ssh/config)
  LOG_LEVEL        Log verbosity (0=error, 1=warn, 2=info, 3=debug)
  LOG_FORMAT       Log format (simple, json, timestamped)

Notes:
  Before overwriting an existing file, restore.sh saves it alongside as
  <file>.restore-safety-<timestamp>. These safety copies are never pruned
  automatically; remove them yourself when you no longer need them.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n | --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            -v | --version)
                local version_file
                version_file="$(dirname "$0")/../VERSION"
                if [[ -f "$version_file" ]]; then
                    echo "$(basename "$0") $(cat "$version_file")"
                else
                    echo "$(basename "$0") unknown (VERSION file not found)" >&2
                    exit 1
                fi
                exit 0
                ;;
            *)
                die "$EX_USAGE" "Unknown option: $1"
                ;;
        esac
    done
}

resolve_source_path() {
    local source="$1"
    if [[ "$source" != /* ]]; then
        source="${HOME}/${source}"
    fi
    source="${source/#\~/$HOME}"
    echo "$source"
}

# Newest backup for a source. Prefers the current naming scheme and falls
# back to the legacy bare-basename scheme, so backups taken before that
# change remain restorable rather than silently orphaned.
find_latest_backup() {
    local source="$1"
    local backup_dir="$2"

    local key basename_key
    key="$(backup_key "$source")"
    basename_key="$(basename "$source")"

    # find with quoted -name patterns: a glob loop would word-split on the
    # space in a path such as "my notes". Read line-wise so filenames with
    # spaces survive, and no nullglob handling is needed.
    local -a found=()
    local match
    while IFS= read -r match; do
        [[ -n "$match" ]] && found+=("$match")
    done < <(find "$backup_dir" -maxdepth 1 -type f \
        \( -name "${key}_*" -o -name "${basename_key}_*" \) 2>/dev/null | sort)

    [[ ${#found[@]} -eq 0 ]] && return 1

    # shellcheck disable=SC2012
    ls -t "${found[@]}" 2>/dev/null | head -n1
}

# Verify a backup against the manifest for its run, before it is allowed to
# overwrite anything.
#
# Returns:
#   0  verified against the manifest
#   1  a manifest covers this backup and the hash does NOT match (refuse)
#   2  no manifest covers this backup (legacy backup; proceed with a notice)
#
# The destination is never taken from the manifest. A manifest is a file in
# the backup store, so it is untrusted: reading only a hash from it means a
# tampered manifest can cause a refusal, but cannot redirect a write.
verify_backup_integrity() {
    local backup="$1"

    # Checked before the manifest, deliberately. The SHA-256 of empty content
    # is a fixed constant, so a manifest written for an empty backup matches
    # it perfectly and the hash check cannot catch this case at all.
    # -s is false for an empty file, and for a missing one; a missing backup is
    # caught by the caller.
    if [[ ! -s "$backup" ]]; then
        log_fail "Refusing to restore $(basename "$backup"): the backup is 0 bytes."
        log_fail "An empty backup would overwrite live config with nothing."
        return 1
    fi

    local manifest
    if ! manifest="$(manifest_for_backup "$backup")"; then
        log_warn "No manifest for $(basename "$backup"); integrity not verified (legacy backup)."
        return 2
    fi

    local expected
    if ! expected="$(manifest_hash_for "$manifest" "$(basename "$backup")")" ||
        [[ -z "$expected" ]]; then
        log_warn "Manifest ${manifest} has no hash for $(basename "$backup"); integrity not verified."
        return 2
    fi

    local actual
    if ! actual="$(sha256_of "$backup")"; then
        log_warn "Could not hash $(basename "$backup"); integrity not verified."
        return 2
    fi

    if [[ "$actual" != "$expected" ]]; then
        log_fail "Integrity check failed for $(basename "$backup"): content does not match the manifest."
        log_fail "Refusing to restore it. Expected sha256 ${expected}, found ${actual}."
        return 1
    fi

    return 0
}

restore_latest_backup() {
    local source="$1"
    local backup_dir="$2"

    source="$(resolve_source_path "$source")"

    local latest_backup
    latest_backup="$(find_latest_backup "$source" "$backup_dir")"

    if [[ -z "$latest_backup" ]]; then
        log_fail "No backup found for: ${source}"
        return 1
    fi

    # Verify before overwriting. A dry run reports the same verdict so it
    # cannot be used to find out that a corrupt backup would have been taken.
    local verdict=0
    verify_backup_integrity "$latest_backup" || verdict=$?

    if [[ $verdict -eq 1 ]]; then
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_pass "Would restore ${source} from ${latest_backup}"
        return 0
    fi

    # The destination may not exist yet (e.g. ~/.ssh on a fresh account)
    mkdir -p "$(dirname "$source")"

    # Preserve whatever is being overwritten so a restore is reversible
    if [[ -f "$source" ]]; then
        local safety
        # This safety copy is the only thing making the restore reversible, so
        # its name must never be reused. A plain $(date +%Y%m%d%H%M%S) had only
        # one-second resolution: two restores of one source within the same
        # second picked the same path and the second silently destroyed the
        # first. Walk past names that are taken instead.
        local stamp n=0
        stamp="$(date +%Y%m%d%H%M%S)"
        while :; do
            if [[ $n -eq 0 ]]; then
                safety="${source}.restore-safety-${stamp}"
            else
                safety="${source}.restore-safety-${stamp}-${n}"
            fi

            # The safety name is predictable. Fail closed rather than write
            # through a symlink someone else planted at that path -- and do not
            # skip past it either, since that would defeat the refusal.
            if [[ -L "$safety" ]]; then
                log_fail "Safety copy path is a symlink, refusing to continue: ${safety}"
                return 1
            fi

            [[ -e "$safety" ]] || break
            n=$((n + 1))
        done

        if ! cp -p "$source" "$safety"; then
            log_fail "Failed to preserve current file: ${source}"
            return 1
        fi
        log_info "Current file preserved as ${safety}"
    fi

    if ! cp -p "$latest_backup" "$source"; then
        log_fail "Failed to restore ${source}"
        return 1
    fi
    log_pass "Restored ${source} from ${latest_backup}"
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Restore"
    echo "========================================="
    echo

    log_info "Searching for latest backups..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run mode - no files will be modified"
    fi

    local failed=0
    local source
    for source in "${BACKUP_SOURCES[@]}"; do
        if ! restore_latest_backup "$source" "${BACKUP_DIR}"; then
            failed=1
        fi
    done

    echo
    if [[ $failed -eq 0 ]]; then
        log_pass "Restore completed successfully."
    else
        log_fail "Restore completed with errors."
        exit 1
    fi
}

main "$@"
