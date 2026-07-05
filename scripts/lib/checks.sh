#!/usr/bin/env bash

###############################################################################
# Library: checks.sh
# Version: 1.0.0
#
# Purpose:
#   Shared validation helpers for the
#   Developer Workstation Framework.
#
# Usage:
#   source scripts/lib/checks.sh
###############################################################################

check_exists() {
    local PATH_TO_CHECK="$1"
    local DESCRIPTION="$2"

    if [[ -e "$PATH_TO_CHECK" ]]; then
        log_pass "$DESCRIPTION"
    else
        log_fail "$DESCRIPTION"
        return 1
    fi
}
