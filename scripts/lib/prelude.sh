#!/usr/bin/env bash

###############################################################################
# Library: prelude.sh
# Version: 1.0.0
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
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/filesystem.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/checks.sh"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/errors.sh"

# Config loader (requires filesystem.sh)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/config.sh"

# Export marker for scripts to check
export PRELUDE_LOADED
