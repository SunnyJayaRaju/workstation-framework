#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: check-project.sh
# Version: see VERSION file
#
# Purpose:
#   Verify the structure and quality of the
#   Developer Workstation Framework repository.
#
# Usage:
#   ./scripts/check-project.sh [OPTIONS]
#
# Exit Codes:
#   0  All checks passed
#   1  One or more checks failed
#   64 Usage error
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/checks.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Verify the structure and quality of the
Developer Workstation Framework repository.

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
                usage
                exit 64
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    # Ensure we operate from the repository root regardless of caller's cwd
    local repo_root
    repo_root="$(cd "${SCRIPT_DIR}/.." && pwd)"
    cd "$repo_root"

    echo "=========================================="
    echo " Developer Workstation Framework"
    echo " Project Quality Check"
    echo "=========================================="
    echo

    # Every check below is recorded rather than allowed to abort the run.
    # check_exists returns 1 on a miss, and under `set -e` that used to kill
    # the script at the first problem, so a single missing directory reported
    # nothing about the rest of the tree.
    local failed=0

    record_path() {
        check_exists "$1" "$2" || failed=1
    }

    record_command() {
        if check_command_exists "$1"; then
            log_pass "$2"
        else
            log_fail "$2"
            failed=1
        fi
    }

    record_path ".git" "Git repository"
    record_path "README.md" "README"
    record_path ".gitignore" ".gitignore"
    record_path ".editorconfig" ".editorconfig"
    record_path ".vscode" "VS Code configuration"

    record_path "VERSION" "VERSION file"
    record_path "Makefile" "Makefile"
    record_path "config" "config directory"
    record_path "docs" "Documentation directory"
    record_path "scripts" "Scripts directory"
    record_path "templates" "Templates directory"
    record_path "tests" "Tests directory"
    record_path "assets" "Assets directory"

    # The scripts/ directory existing says nothing about the utilities inside
    # it. Each one is checked by name so a single deleted utility is reported
    # here, instead of surfacing later as a mysterious "command not found".
    record_path "scripts/backup.sh" "backup.sh"
    record_path "scripts/restore.sh" "restore.sh"
    record_path "scripts/install.sh" "install.sh"
    record_path "scripts/uninstall.sh" "uninstall.sh"
    record_path "scripts/update.sh" "update.sh"
    record_path "scripts/sync.sh" "sync.sh"
    record_path "scripts/repo-clean.sh" "repo-clean.sh"
    record_path "scripts/shell-quality.sh" "shell-quality.sh"
    record_path "scripts/doctor.sh" "doctor.sh"
    record_path "scripts/check-project.sh" "check-project.sh"

    record_command bash "bash"
    record_command git "git"

    echo

    if ((failed)); then
        log_fail "Repository structure check failed."
        exit 1
    fi

    log_pass "Repository structure verified."

    exit 0
}

main "$@"
