#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: install.sh
# Version: 2.1.0
#
# Purpose:
#   Install Developer Workstation Framework utilities.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

: "${INSTALL_DIR:?INSTALL_DIR is not configured}"

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
    clean.sh
    doctor.sh
    restore.sh
    shell-quality.sh
    sync.sh
    uninstall.sh
    update.sh
)

install_lib_directory() {
    local lib_source="${SCRIPT_DIR}/lib"
    local lib_target="${INSTALL_DIR}/lib"

    if [[ ! -d "$lib_source" ]]; then
        log_fail "Library directory not found: ${lib_source}"
        exit 1
    fi

    ensure_directory "${lib_target}"

    if cp -Rp "${lib_source}"/* "${lib_target}/"; then
        log_pass "Library directory installed"
    else
        log_fail "Failed to install library directory"
        exit 1
    fi
}

install_utility() {
    local utility="$1"

    if cp -p "${SCRIPT_DIR}/${utility}" "${INSTALL_DIR}/"; then
        chmod +x "${INSTALL_DIR}/${utility}"
        log_pass "${utility} installed"
    else
        log_fail "Failed to install ${utility}"
        exit 1
    fi
}

verify_installation() {
    local utility

    for utility in "${UTILITIES[@]}"; do
        if [[ -x "${INSTALL_DIR}/${utility}" ]]; then
            log_pass "${utility} verified"
        else
            log_fail "${utility} verification failed"
            exit 1
        fi
    done
}

main() {
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
