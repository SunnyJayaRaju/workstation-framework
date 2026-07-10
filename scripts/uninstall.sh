#!/usr/bin/env bash

###############################################################################
# Script: uninstall.sh
# Version: 2.0.0
#
# Purpose:
#   Remove Developer Workstation Framework utilities installed
#   in ~/.local/bin.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

INSTALL_DIR="${HOME}/.local/bin"
readonly INSTALL_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

remove_utility() {
    local utility="$1"

    if [[ -f "${INSTALL_DIR}/${utility}" ]]; then
        rm -f "${INSTALL_DIR}/${utility}"
        log_pass "${utility} removed"
    else
        log_info "${utility} not installed"
    fi
}

main() {
    echo
    echo "========================================="
    echo " Developer Workstation Uninstaller"
    echo "========================================="
    echo

    log_info "Removing installed framework utilities..."

    remove_utility "backup.sh"
    remove_utility "doctor.sh"
    remove_utility "shell-quality.sh"

    echo
    log_pass "Framework utilities removed successfully."
}

main "$@"
