#!/usr/bin/env bash

###############################################################################
# Library: checks.sh
# Version: see VERSION file
#
# Purpose:
#   Shared validation helpers for the
#   Developer Workstation Framework.
#   Non-terminating predicate versions (return 0/1).
#
#   File and directory predicates live in filesystem.sh (file_exists,
#   directory_exists). They were duplicated here under check_* names with
#   zero call sites; the duplicates are gone rather than maintained.
###############################################################################

check_command_exists() {
    local command="$1"

    command -v "$command" >/dev/null 2>&1
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
