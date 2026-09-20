#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: install.sh
# Version: 3.1.0
#
# Purpose:
#   Install Developer Workstation Framework utilities.
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

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

readonly UTILITIES=(
    backup.sh
    bootstrap.sh
    check-project.sh
    repo-clean.sh
    doctor.sh
    restore.sh
    shell-quality.sh
    sync.sh
    uninstall.sh
    update.sh
)

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install Developer Workstation Framework utilities.

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
                echo "install.sh 3.1.0"
                exit 0
                ;;
            *)
                die EX_USAGE "Unknown option: $1"
                ;;
        esac
    done
}

install_lib_directory() {
    local lib_source="${SCRIPT_DIR}/lib"
    local lib_target="${INSTALL_DIR}/lib"

    require_directory "$lib_source" EX_OSFILE

    ensure_directory "${lib_target}"

    if cp -Rp "${lib_source}"/* "${lib_target}/"; then
        log_pass "Library directory installed"
    else
        die EX_IOERR "Failed to install library directory"
    fi
}

install_utility() {
    local utility="$1"

    if cp -p "${SCRIPT_DIR}/${utility}" "${INSTALL_DIR}/"; then
        chmod +x "${INSTALL_DIR}/${utility}"
        log_pass "${utility} installed"
    else
        die EX_IOERR "Failed to install ${utility}"
    fi
}

verify_installation() {
    local utility

    for utility in "${UTILITIES[@]}"; do
        if [[ -x "${INSTALL_DIR}/${utility}" ]]; then
            log_pass "${utility} verified"
        else
            die EX_SOFTWARE "${utility} verification failed"
        fi
    done
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Installer"
    echo "========================================="
    echo

    log_info "Preparing installation..."

    ensure_directory "${INSTALL_DIR}"

    echo

    log_info "Installing library directory..."

    install_lib_directory

    echo

    log_info "Installing utilities..."

    local utility

    for utility in "${UTILITIES[@]}"; do
        install_utility "${utility}"
    done

    echo

    log_info "Verifying installation..."

    verify_installation

    echo

    log_pass "Installation completed successfully."
}

main "$@"
