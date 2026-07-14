#!/usr/bin/env bash

###############################################################################
# Script: restore.sh
# Version: 2.0.0
#
# Purpose:
#   Restore the most recent .zshrc backup created by backup.sh.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

load_config

: "${BACKUP_DIR:?BACKUP_DIR is not configured}"

readonly BACKUP_DIR

SOURCE="${HOME}/.zshrc"
readonly SOURCE

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

restore_latest_backup() {
    local latest_backup

    latest_backup="$(
        find "${BACKUP_DIR}" \
            -maxdepth 1 \
            -type f \
            -name 'zshrc_*' \
            -print0 |
            xargs -0 ls -t 2>/dev/null |
            head -n 1
    )"

    if [[ -z "${latest_backup}" ]]; then
        log_fail "No backups found."
        exit 1
    fi

    cp -p "${latest_backup}" "${SOURCE}"

    log_pass "Restored:"
    echo "  ${latest_backup}"
}

main() {
    echo
    echo "========================================="
    echo " Developer Workstation Restore"
    echo "========================================="
    echo

    log_info "Looking for latest backup..."

    restore_latest_backup

    echo

    log_pass ".zshrc restored successfully."
}

main "$@"
