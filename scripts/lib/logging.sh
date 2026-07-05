#!/usr/bin/env bash

###############################################################################
# Library: logging.sh
# Version: 1.0.0
#
# Purpose:
#   Shared logging helpers for the
#   Developer Workstation Framework.
#
# Usage:
#   source scripts/lib/logging.sh
###############################################################################

PASS_MARK="✓"
FAIL_MARK="✗"
INFO_MARK="ℹ"

log_pass() {
    printf "%s %s\n" "$PASS_MARK" "$1"
}

log_fail() {
    printf "%s %s\n" "$FAIL_MARK" "$1"
}

log_info() {
    printf "%s %s\n" "$INFO_MARK" "$1"
}
