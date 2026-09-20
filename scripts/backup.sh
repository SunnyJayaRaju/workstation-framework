#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: backup.sh
# Version: 3.1.0
#
# Purpose:
#   Create timestamped backups of configured configuration files.
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

# Configurable backup sources - can be overridden via BACKUP_SOURCES env var
# Format: space-separated list of paths (relative to HOME or absolute)
IFS=' ' read -r -a BACKUP_SOURCES <<<"${BACKUP_SOURCES:-${HOME}/.zshrc ${HOME}/.gitconfig ${HOME}/.ssh/config}"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly TIMESTAMP

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Create timestamped backups of configured configuration files.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Environment Variables:
  BACKUP_DIR       Backup destination directory (required)
  BACKUP_SOURCES   Space-separated list of files to backup (default: .zshrc .gitconfig .ssh/config)
  LOG_LEVEL        Log verbosity (0=error, 1=warn, 2=info, 3=debug)
  LOG_FORMAT       Log format (simple, json, timestamped)

Examples:
  BACKUP_DIR=~/backups $0
  BACKUP_DIR=/tmp/backups BACKUP_SOURCES=".zshrc .vimrc" $0
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
                echo "backup.sh 3.1.0"
                exit 0
                ;;
            *)
                die EX_USAGE "Unknown option: $1"
                ;;
        esac
    done
}

backup_file() {
    local source="$1"
    local dest_dir="$2"
    local timestamp="$3"

    # Expand tilde and relative paths
    if [[ "$source" != /* ]]; then
        source="${HOME}/${source}"
    fi
    source="${source/#\~/$HOME}"

    local basename
    basename="$(basename "$source")"
    local destination="${dest_dir}/${basename}_${timestamp}"

    if [[ ! -f "$source" ]]; then
        log_fail "Source file not found: ${source}"
        return 1
    fi

    cp -p "$source" "$destination"
    log_pass "Backed up: ${source} -> ${destination}"
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Backup"
    echo "========================================="
    echo

    log_info "Preparing backup..."

    ensure_directory "${BACKUP_DIR}"

    local failed=0
    local source
    for source in "${BACKUP_SOURCES[@]}"; do
        if ! backup_file "$source" "${BACKUP_DIR}" "${TIMESTAMP}"; then
            failed=1
        fi
    done

    echo
    if [[ $failed -eq 0 ]]; then
        log_pass "Backup completed successfully."
    else
        log_fail "Backup completed with errors."
        exit 1
    fi
}

main "$@"
