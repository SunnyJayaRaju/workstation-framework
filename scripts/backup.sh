#!/usr/bin/env bash

###############################################################################
# Script: backup.sh
# Version: 2.0.0
#
# Purpose:
#   Create a timestamped backup of ~/.zshrc.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

: "${BACKUP_DIR:?BACKUP_DIR is not configured}"

readonly BACKUP_DIR

SOURCE="${HOME}/.zshrc"
readonly SOURCE

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly TIMESTAMP

DESTINATION="${BACKUP_DIR}/zshrc_${TIMESTAMP}"
readonly DESTINATION

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

main() {

    echo
    echo "========================================="
    echo " Developer Workstation Backup"
    echo "========================================="
    echo

    log_info "Preparing backup..."

    ensure_directory "${BACKUP_DIR}"

    if [[ ! -f "${SOURCE}" ]]; then
        log_fail "Source file not found."
        echo "  ${SOURCE}"
        exit 1
    fi

    cp -p "${SOURCE}" "${DESTINATION}"

    log_pass "Backup created."

    echo "  ${DESTINATION}"

    echo

    log_pass "Backup completed successfully."
}

main "$@"
