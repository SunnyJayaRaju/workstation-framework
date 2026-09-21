#!/usr/bin/env bash

###############################################################################
# Library: checks.sh
#
# Purpose:
#   Shared validation helpers for the
#   Developer Workstation Framework.
#   Non-terminating predicate versions (return 0/1).
###############################################################################

check_command_exists() {
    local command="$1"

    command -v "$command" >/dev/null 2>&1
}

check_file_exists() {
    local file="$1"

    [[ -f "$file" ]]
}

check_directory_exists() {
    local directory="$1"

    [[ -d "$directory" ]]
}

check_variable_set() {
    local variable="$1"

    [[ -n "${!variable:-}" ]]
}

# Check path exists and log result (backward compatible with check-project.sh)
check_exists() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" ]]; then
        log_pass "$description"
        return 0
    else
        log_fail "$description"
        return 1
    fi
}
