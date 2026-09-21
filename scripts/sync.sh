#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: sync.sh
# Version: see VERSION file
#
# Purpose:
#   Check synchronization status between the local repository
#   and its upstream remote.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/errors.sh
source "${SCRIPT_DIR}/lib/errors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Check synchronization status between the local repository
and its upstream remote.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit
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
                echo "$(basename "$0") $(cat "$(dirname "$0")/../VERSION")"
                exit 0
                ;;
            *)
                die EX_USAGE "Unknown option: $1"
                ;;
        esac
    done
}

get_upstream_remote() {
    local branch
    branch="$(git branch --show-current)"

    if [[ -z "$branch" ]]; then
        return 1
    fi

    # Try to get the upstream remote for the current branch
    local upstream
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)"

    if [[ -n "$upstream" ]]; then
        # Extract remote name from upstream (e.g., "origin/main" -> "origin")
        echo "${upstream%%/*}"
        return 0
    fi

    # Fallback: check if 'origin' exists
    if git remote get-url origin >/dev/null 2>&1; then
        echo "origin"
        return 0
    fi

    # Fallback: use first remote
    git remote | head -n1
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Sync"
    echo "========================================="
    echo

    if ! command -v git >/dev/null 2>&1; then
        log_fail "Git is not installed."
        exit 69
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_fail "Current directory is not a Git repository."
        exit 128
    fi

    # CI checkouts (actions/checkout on pull_request events) run in a
    # detached-HEAD state where branch/upstream comparisons are impossible.
    # Report the commit and finish cleanly instead of failing.
    local branch
    branch="$(git branch --show-current)"

    if [[ -z "${branch}" ]]; then
        local detached_sha
        detached_sha="$(git rev-parse --short HEAD)"
        log_info "Detached HEAD detected (typical in CI environments)."
        echo "Checked-out commit: ${detached_sha}"
        echo
        log_pass "Synchronization check completed."
        return 0
    fi

    local remote
    remote="$(get_upstream_remote)"

    if [[ -z "$remote" ]]; then
        log_fail "No Git remote configured. Cannot check synchronization."
        echo "Run 'git remote add origin <url>' to add a remote."
        exit 1
    fi

    log_info "Fetching latest remote information from ${remote}..."

    git fetch --prune "${remote}"

    echo

    log_info "Repository status..."

    git status --short --branch

    echo

    local upstream_branch="${remote}/${branch}"

    # Check if upstream branch exists
    if ! git rev-parse --verify "${upstream_branch}" >/dev/null 2>&1; then
        log_info "Upstream branch '${upstream_branch}' does not exist yet."
        echo
        log_pass "Synchronization check completed."
        return 0
    fi

    echo "Current branch : ${branch}"
    echo "Tracking branch: ${upstream_branch}"

    echo

    local ahead
    local behind

    ahead="$(git rev-list --count "${upstream_branch}..${branch}" 2>/dev/null || echo 0)"
    behind="$(git rev-list --count "${branch}..${upstream_branch}" 2>/dev/null || echo 0)"

    if [[ "${ahead}" -eq 0 && "${behind}" -eq 0 ]]; then
        log_pass "Repository is synchronized with ${remote}."
    elif [[ "${ahead}" -gt 0 && "${behind}" -eq 0 ]]; then
        log_info "Local branch is ${ahead} commit(s) ahead of ${remote}."
    elif [[ "${ahead}" -eq 0 && "${behind}" -gt 0 ]]; then
        log_info "Local branch is ${behind} commit(s) behind ${remote}."
    else
        log_info "Branches have diverged."
        echo "  Ahead : ${ahead}"
        echo "  Behind: ${behind}"
    fi

    echo
    log_pass "Synchronization check completed."
}

main "$@"
