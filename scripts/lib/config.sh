#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Configuration Loader
###############################################################################

CONFIG_DIR=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../../config" 2>/dev/null &&
        pwd || echo "${HOME}/.workstation/config"
)
readonly CONFIG_DIR

load_config() {

    local default_config="${CONFIG_DIR}/default.conf"
    local user_config="${CONFIG_DIR}/user.conf"

    if [[ -f "$default_config" ]]; then
        # shellcheck disable=SC1090
        source "$default_config"
    else
        # Fallback defaults when config files don't exist
        : "${INSTALL_DIR:=$HOME/.local/bin}"
        : "${BACKUP_DIR:=$HOME/.workstation/backups}"
        : "${ENABLE_BACKUP:=true}"
        : "${ENABLE_DOCTOR:=true}"
        : "${ENABLE_CLEANUP:=true}"
        : "${ENABLE_SHELLCHECK:=true}"
        : "${ENABLE_SHFMT:=true}"
    fi

    if [[ -f "$user_config" ]]; then
        # shellcheck disable=SC1090
        source "$user_config"
    fi
}

config_exists() {

    [[ -d "$CONFIG_DIR" ]]
}
