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

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/errors.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Update the local repository, reinstall framework utilities,
and verify the installation.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Environment Variables:
  INSTALL_DIR      Installation directory (required, from config)
  ENABLE_DOCTOR    Run the health check afterwards (default: true)
  LOG_LEVEL        Log verbosity (0=error, 1=warn, 2=info, 3=debug)
  LOG_FORMAT       Log format (simple, json, timestamped)
EOF
}

# Parsed before any work, so -h/-v never trigger a git pull or a reinstall.
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h | --help)
                usage
                exit 0
                ;;
            -v | --version)
                local version_file
                version_file="$(dirname "$0")/../VERSION"
                if [[ -f "$version_file" ]]; then
                    echo "$(basename "$0") $(cat "$version_file")"
                else
                    echo "$(basename "$0") unknown (VERSION file not found)" >&2
                    exit 1
                fi
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit "$EX_USAGE"
                ;;
        esac
    done
}

main() {
    parse_args "$@"

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
    local branch
    branch="$(git -C "$REPO_ROOT" branch --show-current)"

    if [[ -z "$branch" ]]; then
        log_info "Detached HEAD detected — skipping repository pull."
    elif ! git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
        # No upstream: `git pull --ff-only` would fail and, under `set -e`,
        # kill the whole script before the reinstall. Warn and carry on.
        log_warn "No upstream tracking branch for '${branch}'; skipping git pull."
        log_warn "Run 'git push -u origin ${branch}' to enable automatic updates."
    else
        log_info "Updating repository..."

        git -C "$REPO_ROOT" pull --ff-only
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
