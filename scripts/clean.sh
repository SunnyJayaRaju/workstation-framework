#!/usr/bin/env bash

###############################################################################
# Script: clean.sh
# Version: 2.0.0
#
# Purpose:
#   Remove temporary files generated during development without
#   affecting tracked project files.
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
    echo " Developer Workstation Cleanup"
    echo "========================================="
    echo

    log_info "Removing temporary files..."

    find . -type f -name "*.orig" -print -delete
    find . -type f -name "*~" -print -delete
    find . -type f -name ".DS_Store" -print -delete

    echo

    log_pass "Cleanup completed successfully."
}

main "$@"
