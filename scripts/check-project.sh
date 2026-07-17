#!/usr/bin/env bash

###############################################################################
# Script: check-project.sh
# Version: 2.0.0
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/checks.sh"

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
