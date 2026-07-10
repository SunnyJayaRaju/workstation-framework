#!/usr/bin/env bash

###############################################################################
# Script: update.sh
# Version: 2.0.0
#
# Purpose:
#   Update the local repository, reinstall framework utilities,
#   and verify the installation.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

main() {
    echo
    echo "========================================="
    echo " Developer Workstation Updater"
    echo "========================================="
    echo

    log_info "Updating repository..."

    git pull --ff-only

    echo

    log_info "Installing latest framework utilities..."

    "${SCRIPT_DIR}/install.sh"

    echo

    log_info "Running framework health check..."

    "${SCRIPT_DIR}/doctor.sh"

    echo

    log_pass "Framework updated successfully."
}

main "$@"
