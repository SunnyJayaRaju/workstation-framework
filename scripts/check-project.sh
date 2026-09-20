#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: check-project.sh
# Version: 3.0.0
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
                echo "check-project.sh 3.0.0"
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

    echo "=========================================="
    echo " Developer Workstation Framework"
    echo " Project Quality Check"
    echo "=========================================="
    echo

    check_exists ".git" "Git repository"
    check_exists "README.md" "README"
    check_exists ".gitignore" ".gitignore"
    check_exists ".editorconfig" ".editorconfig"
    check_exists ".vscode" "VS Code configuration"

    check_exists "docs" "Documentation directory"
    check_exists "scripts" "Scripts directory"
    check_exists "templates" "Templates directory"
    check_exists "tests" "Tests directory"
    check_exists "assets" "Assets directory"

    echo
    log_pass "Repository structure verified."

    exit 0
}

main "$@"
