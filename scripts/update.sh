#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: update.sh
# Version: 3.0.0
#
# Purpose:
#   Update the local repository, reinstall framework utilities,
#   and verify the installation.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

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

    # git pull requires an attached branch; skip gracefully on detached HEAD
    # (typical in CI checkouts) — install + doctor below still run fully.
    if [[ -n "$(git branch --show-current)" ]]; then
        log_info "Updating repository..."

        git pull --ff-only
    else
        log_info "Detached HEAD detected — skipping repository pull."
    fi

    echo

    log_info "Installing latest framework utilities..."

    "${SCRIPT_DIR}/install.sh"

    echo

    # Run doctor if enabled
    if [[ "${ENABLE_DOCTOR:-true}" == "true" ]]; then
        log_info "Running framework health check..."

        "${SCRIPT_DIR}/doctor.sh"
    else
        log_info "Skipping health check (ENABLE_DOCTOR=false)"
    fi

    echo

    log_pass "Framework updated successfully."
}

main "$@"
