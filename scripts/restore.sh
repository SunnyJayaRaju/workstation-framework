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
IFS=' ' read -r -a BACKUP_SOURCES <<<"${BACKUP_SOURCES:-${HOME}/.zshrc ${HOME}/.gitconfig ${HOME}/.ssh/config}"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

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

restore_latest_backup() {
    local source="$1"
    local backup_dir="$2"

    source="$(resolve_source_path "$source")"

    local basename
    basename="$(basename "$source")"

    local latest_backup=""

    # Find the latest backup by modification time (portable)
    # Use ls -t which works on both macOS and Linux
    # shellcheck disable=SC2012
    local files
    files=("${backup_dir}/${basename}_"*)
    if [[ ${#files[@]} -eq 1 && ! -e "${files[0]}" ]]; then
        # Nullglob case - no matches
        files=()
    fi
    if [[ ${#files[@]} -gt 0 ]]; then
        # shellcheck disable=SC2012
        latest_backup=$(ls -t "${files[@]}" 2>/dev/null | head -n1)
    fi

    if [[ -z "$latest_backup" ]]; then
        log_fail "No backup found for: ${source}"
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
        safety="${source}.restore-safety-$(date +%Y%m%d%H%M%S)"

        # The safety name is predictable. Fail closed rather than write
        # through a symlink someone else planted at that path.
        if [[ -L "$safety" ]]; then
            log_fail "Safety copy path is a symlink, refusing to continue: ${safety}"
            return 1
        fi

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
