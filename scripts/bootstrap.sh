#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: bootstrap.sh
# Version: 1.1.0
#
# Purpose:
#   Install Developer Workstation Framework utilities.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

load_config

readonly LOCAL_BIN="$INSTALL_DIR"

echo
echo "========================================="
echo " Developer Workstation Bootstrap"
echo "========================================="
echo

mkdir -p "$LOCAL_BIN"

echo "Installing utilities..."

cp -p "$SCRIPT_DIR/backup.sh" "$LOCAL_BIN/backup.sh"

cp -p "$SCRIPT_DIR/shell-quality.sh" "$LOCAL_BIN/shell-quality.sh"

echo "✓ backup.sh installed"

echo "✓ shell-quality.sh installed"

echo

echo "Bootstrap completed successfully."
