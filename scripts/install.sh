#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: install.sh
# Version: 2.0.0
#
# Purpose:
#   Install Developer Workstation Framework utilities into ~/.local/bin.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

load_config

readonly INSTALL_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

install_utility() {
    local utility="$1"

    if cp -p "${SCRIPT_DIR}/${utility}" "${INSTALL_DIR}/"; then
        log_pass "${utility} installed"
    else
        log_fail "Failed to install ${utility}"
        exit 1
    fi
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

    log_info "Installing utilities..."

    install_utility "backup.sh"
    install_utility "doctor.sh"
    install_utility "shell-quality.sh"

    echo

    log_info "Verifying installation..."

    for utility in \
        backup.sh \
        doctor.sh \
        shell-quality.sh; do
        if [[ -x "${INSTALL_DIR}/${utility}" ]]; then
            log_pass "${utility} verified"
        else
            log_fail "${utility} verification failed"
            exit 1
        fi
    done

    echo
    log_pass "Installation completed successfully."
}

main "$@"
