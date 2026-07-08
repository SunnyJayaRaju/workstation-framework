#!/usr/bin/env bash

###############################################################################
# Script: shell-quality.sh
# Version: 1.0.0
#
# Purpose:
#   Run quality checks against a shell script.
###############################################################################

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage:"
    echo "  $0 <shell-script>"
    exit 1
fi

readonly SCRIPT="$1"

if [[ ! -f "$SCRIPT" ]]; then
    echo "File not found:"
    echo "  $SCRIPT"
    exit 1
fi

echo
echo "========================================="
echo " Shell Quality Report"
echo "========================================="
echo

echo "Checking Bash syntax..."
bash -n "$SCRIPT"

echo "Checking ShellCheck..."
shellcheck "$SCRIPT"

echo "Checking formatting..."
shfmt -d "$SCRIPT"

echo
echo "========================================="
echo "✓ Quality checks passed"
echo "========================================="
