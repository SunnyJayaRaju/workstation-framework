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

for utility in \
    backup.sh \
    doctor.sh \
    shell-quality.sh; do

    cp -p "${SCRIPT_DIR}/${utility}" "${LOCAL_BIN}/${utility}"

    echo "✓ ${utility} installed"

done

echo

echo "Bootstrap completed successfully."
