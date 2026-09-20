#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: uninstall.sh
# Version: 3.1.0
#
# Purpose:
#   Remove Developer Workstation Framework utilities.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

# shellcheck source=lib/errors.sh
source "${SCRIPT_DIR}/lib/errors.sh"

require_var INSTALL_DIR EX_CONFIG

readonly INSTALL_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Remove Developer Workstation Framework utilities.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Environment Variables:
  INSTALL_DIR      Installation directory (required, from config)
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
                echo "uninstall.sh 3.1.0"
                exit 0
                ;;
            *)
                die EX_USAGE "Unknown option: $1"
                ;;
        esac
    done
}

remove_utility() {
    local utility="$1"

    if [[ -f "${INSTALL_DIR}/${utility}" ]]; then
        rm -f "${INSTALL_DIR}/${utility}"
        log_pass "${utility} removed"
    else
        log_info "${utility} not installed"
    fi
}

remove_lib_directory() {
    local lib_target="${INSTALL_DIR}/lib"

    if [[ -d "$lib_target" ]]; then
        rm -rf "${lib_target}"
        log_pass "Library directory removed"
    else
        log_info "Library directory not installed"
    fi
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Uninstaller"
    echo "========================================="
    echo

    log_info "Removing installed framework utilities..."

    remove_utility "backup.sh"
    remove_utility "check-project.sh"
    remove_utility "repo-clean.sh"
    remove_utility "doctor.sh"
    remove_utility "restore.sh"
    remove_utility "shell-quality.sh"
    remove_utility "sync.sh"
    remove_utility "uninstall.sh"
    remove_utility "update.sh"

    echo

    log_info "Removing library directory..."

    remove_lib_directory

    echo
    log_pass "Framework utilities removed successfully."
}

main "$@"
