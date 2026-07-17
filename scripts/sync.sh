#!/usr/bin/env bash

###############################################################################
# Script: sync.sh
# Version: 2.0.0
#
# Purpose:
#   Check synchronization status between the local repository
#   and its upstream remote.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

main() {
    echo
    echo "========================================="
    echo " Developer Workstation Sync"
    echo "========================================="
    echo

    if ! command -v git >/dev/null 2>&1; then
        log_fail "Git is not installed."
        exit 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_fail "Current directory is not a Git repository."
        exit 1
    fi

    log_info "Fetching latest remote information..."

    git fetch --prune origin

    echo

    log_info "Repository status..."

    git status --short --branch

    echo

    local branch
    branch="$(git branch --show-current)"

    echo "Current branch : ${branch}"
    echo "Tracking branch: origin/${branch}"

    echo

    local ahead
    local behind

    ahead="$(git rev-list --count "origin/${branch}..${branch}")"
    behind="$(git rev-list --count "${branch}..origin/${branch}")"

    if [[ "${ahead}" -eq 0 && "${behind}" -eq 0 ]]; then
        log_pass "Repository is synchronized with origin."
    elif [[ "${ahead}" -gt 0 && "${behind}" -eq 0 ]]; then
        log_info "Local branch is ${ahead} commit(s) ahead of origin."
    elif [[ "${ahead}" -eq 0 && "${behind}" -gt 0 ]]; then
        log_info "Local branch is ${behind} commit(s) behind origin."
    else
        log_info "Branches have diverged."
        echo "  Ahead : ${ahead}"
        echo "  Behind: ${behind}"
    fi

    echo
    log_pass "Synchronization check completed."
}

main "$@"
