#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: restore.sh
# Version: 3.1.0
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

require_var BACKUP_DIR EX_CONFIG

readonly BACKUP_DIR

# Configurable backup sources - must match backup.sh
IFS=' ' read -r -a BACKUP_SOURCES <<<"${BACKUP_SOURCES:-${HOME}/.zshrc ${HOME}/.gitconfig ${HOME}/.ssh/config}"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Restore the latest backups for configured configuration files.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Environment Variables:
  BACKUP_DIR       Backup source directory (required)
  BACKUP_SOURCES   Space-separated list of files to restore (default: .zshrc .gitconfig .ssh/config)
  LOG_LEVEL        Log verbosity (0=error, 1=warn, 2=info, 3=debug)
  LOG_FORMAT       Log format (simple, json, timestamped)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h | --help)
                usage
                exit 0
                ;;
            -v | --version)
                echo "restore.sh 3.1.0"
                exit 0
                ;;
            *)
                die EX_USAGE "Unknown option: $1"
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

    # Use ls -t to get the latest file by modification time
    # shellcheck disable=SC2012
    latest_backup=$(ls -t "${backup_dir}/${basename}_"* 2>/dev/null | head -n1)

    if [[ -z "$latest_backup" ]]; then
        log_fail "No backup found for: ${source}"
        return 1
    fi

    cp -p "$latest_backup" "$source"
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
