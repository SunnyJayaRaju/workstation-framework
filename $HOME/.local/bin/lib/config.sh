#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Configuration Loader - Safe parser for KEY=VALUE config files
###############################################################################

# Determine CONFIG_DIR - handle both sourced from file and command line
_config_src="${BASH_SOURCE[0]:-${0}}"
CONFIG_DIR=$(
    cd "$(dirname "${_config_src}")/../../config" 2>/dev/null &&
        pwd || echo "${HOME}/.workstation/config"
)
unset _config_src
readonly CONFIG_DIR

# Parse a config file safely - only allows KEY=VALUE lines
# Ignores comments, empty lines, and exports
parse_config_file() {
    local file="$1"
    local prefix="${2:-}"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Match KEY=VALUE pattern (KEY: uppercase, underscores, digits)
        if [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Strip leading/trailing whitespace from value
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"

            # Remove surrounding quotes if present
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^'(.*)'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # Only set if not already set (environment takes precedence)
            if [[ -z "${!key:-}" ]]; then
                eval "${prefix}${key}=\${value}"
            fi
        fi
    done <"$file"
}

load_config() {
    local default_config="${CONFIG_DIR}/default.conf"
    local user_config="${CONFIG_DIR}/user.conf"

    # Load defaults first (lowest precedence)
    parse_config_file "$default_config"

    # Load user overrides (higher precedence)
    parse_config_file "$user_config"
}

config_exists() {
    [[ -d "$CONFIG_DIR" ]]
}
