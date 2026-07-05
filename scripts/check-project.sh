#!/usr/bin/env bash

###############################################################################
# Script: check-project.sh
# Version: 1.0.0
#
# Purpose:
#   Verify the structure and quality of the
#   Developer Workstation Framework repository.
#
# Usage:
#   ./scripts/check-project.sh
#
# Exit Codes:
#   0  All checks passed
#   1  One or more checks failed
###############################################################################

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/logging.sh"

echo "=========================================="
echo " Developer Workstation Framework"
echo " Project Quality Check"
echo "=========================================="
echo

check_exists() {
    local PATH_TO_CHECK="$1"
    local DESCRIPTION="$2"

    if [[ -e "$PATH_TO_CHECK" ]]; then
        log_pass "$DESCRIPTION"
    else
        log_fail "$DESCRIPTION"
        exit 1
    fi
}

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
echo "Repository structure verified."

exit 0
