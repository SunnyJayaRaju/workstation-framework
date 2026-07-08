#!/usr/bin/env bash

###############################################################################
# Script: bootstrap.sh
# Version: 1.1.0
#
# Purpose:
#   Install Developer Workstation Framework utilities.
###############################################################################

set -euo pipefail

readonly LOCAL_BIN="$HOME/.local/bin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR

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
