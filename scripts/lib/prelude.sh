#!/usr/bin/env bash

###############################################################################
# Library: prelude.sh
# Version: see VERSION file
#
# Purpose:
#   Single entry point to load all standard framework libraries.
#   Use this instead of sourcing individual libraries.
#
# Usage:
#   source scripts/lib/prelude.sh
###############################################################################

# Prevent multiple loading
if [[ -n "${PRELUDE_LOADED:-}" ]]; then
    return 0
fi
readonly PRELUDE_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Core libraries (load in dependency order)
# These are sibling files in the same directory
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/colors.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/logging.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/filesystem.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/checks.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/errors.sh"

# Config loader
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.sh"

# Export marker for scripts to check
export PRELUDE_LOADED
