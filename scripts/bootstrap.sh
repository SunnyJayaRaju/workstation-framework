#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: bootstrap.sh
# Version: 2.0.0
#
# Purpose:
#   Install Developer Workstation Framework utilities (alias for install.sh).
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

exec "${SCRIPT_DIR}/install.sh" "$@"
