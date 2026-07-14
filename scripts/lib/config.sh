#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Configuration Loader
###############################################################################

CONFIG_DIR=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../../config" &&
        pwd
)
readonly CONFIG_DIR

load_config() {

    local default_config="${CONFIG_DIR}/default.conf"
    local user_config="${CONFIG_DIR}/user.conf"

    if [[ -f "$default_config" ]]; then
        # shellcheck disable=SC1090
        source "$default_config"
    fi

    if [[ -f "$user_config" ]]; then
        # shellcheck disable=SC1090
        source "$user_config"
    fi
}

config_exists() {

    [[ -d "$CONFIG_DIR" ]]
}
