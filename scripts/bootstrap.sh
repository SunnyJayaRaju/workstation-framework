#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: bootstrap.sh
# Version: 3.1.0
#
# Purpose:
#   Install Developer Workstation Framework utilities (alias for install.sh).
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

exec "${SCRIPT_DIR}/install.sh" "$@"
