#!/usr/bin/env bash

###############################################################################
# Library: checks.sh
#
# Purpose:
#   Shared validation helpers for the
#   Developer Workstation Framework.
###############################################################################

check_exists() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" ]]; then
        log_pass "$description"
    else
        log_fail "$description"
        return 1
    fi
}

require_command() {
    local command="$1"

    command -v "$command" >/dev/null 2>&1
}

require_file() {
    local file="$1"

    [[ -f "$file" ]]
}

require_directory() {
    local directory="$1"

    [[ -d "$directory" ]]
}

require_variable() {
    local variable="$1"

    [[ -n "${!variable:-}" ]]
}
