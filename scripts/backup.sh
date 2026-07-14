#!/usr/bin/env bash

###############################################################################
# Script: backup.sh
# Version: 1.0.0
#
# Purpose:
#   Create a timestamped backup of important configuration files.
#
# Current Scope:
#   - ~/.zshrc
#
# Planned Future Scope:
#   - ~/.gitconfig
#   - ~/.config
#   - Starship configuration
#   - Topgrade configuration
#
# Requirements:
#   - Bash
#   - cp
#   - date
#
# Exit Codes:
#   0  Success
#   1  Failure
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

load_config

readonly BACKUP_DIR

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly TIMESTAMP

readonly SOURCE="$HOME/.zshrc"

readonly DESTINATION="$BACKUP_DIR/zshrc_${TIMESTAMP}"

if [[ ! -f "$SOURCE" ]]; then
    echo "❌ Source file not found:"
    echo "   $SOURCE"
    exit 1
fi

cp -p "$SOURCE" "$DESTINATION"

echo "✅ Backup created:"
echo "$DESTINATION"
