#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: update.sh
# Version: see VERSION file
#
# Purpose:
#   Update the local repository, reinstall framework utilities,
#   and verify the installation.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Operate on the framework's own repository, never on whatever repository
# happens to be the caller's current working directory.
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT

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

    if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_fail "Not a Git repository: ${REPO_ROOT}"
        exit 128
    fi

    # git pull requires an attached branch; skip gracefully on detached HEAD
    # (typical in CI checkouts) — install + doctor below still run fully.
    if [[ -n "$(git -C "$REPO_ROOT" branch --show-current)" ]]; then
        log_info "Updating repository..."

        git -C "$REPO_ROOT" pull --ff-only
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
