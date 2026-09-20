#!/usr/bin/env bash

###############################################################################
# Library: filesystem.sh
# Version: 1.0.0
#
# Purpose:
#   Shared filesystem helpers for the
#   Developer Workstation Framework.
#
# Usage:
#   source scripts/lib/filesystem.sh
###############################################################################

directory_exists() {
    local DIRECTORY="$1"

    [[ -d "$DIRECTORY" ]]
}

file_exists() {
    local FILE="$1"

    [[ -f "$FILE" ]]
}

create_directory() {
    local DIRECTORY="$1"

    mkdir -p "$DIRECTORY"
}

ensure_directory() {
    local DIRECTORY="$1"

    if directory_exists "$DIRECTORY"; then
        return 0
    fi

    create_directory "$DIRECTORY"
}

copy_file() {
    local SOURCE="$1"
    local DESTINATION="$2"

    cp -p "$SOURCE" "$DESTINATION"
}

remove_file() {
    local FILE="$1"

    rm -f "$FILE"
}
