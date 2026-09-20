#!/usr/bin/env bash

###############################################################################
# Library: secrets.sh
# Version: 1.0.0
#
# Purpose:
#   Secure secrets handling for the Developer Workstation Framework.
#   Supports macOS Keychain and 1Password CLI.
#
# Usage:
#   source scripts/lib/secrets.sh
#   secret=$(get_secret "github-token")
#   store_secret "api-key" "my-secret-value"
###############################################################################

# Prevent multiple loading
if [[ -n "${SECRETS_LOADED:-}" ]]; then
    return 0
fi
readonly SECRETS_LOADED=1

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/errors.sh"

# Check if 1Password CLI is available
has_op_cli() {
    command -v op >/dev/null 2>&1
}

# Check if macOS Keychain is available
has_keychain() {
    command -v security >/dev/null 2>&1
}

# Get secret from 1Password
# Usage: get_secret_op "item-name" "field-name" ["vault-name"]
get_secret_op() {
    local item_name="$1"
    local field_name="$2"
    local vault_name="${3:-}"

    if ! has_op_cli; then
        die EX_UNAVAILABLE "1Password CLI (op) not found"
    fi

    local args=("item" "get" "$item_name" "--fields" "$field_name" "--format" "json")
    if [[ -n "$vault_name" ]]; then
        args+=("--vault" "$vault_name")
    fi

    local result
    result=$(op "${args[@]}" 2>/dev/null) || return 1
    echo "$result" | jq -r '.value // empty'
}

# Store secret in 1Password
# Usage: store_secret_op "item-name" "field-name" "value" ["vault-name"]
store_secret_op() {
    local item_name="$1"
    local field_name="$2"
    local value="$3"
    local vault_name="${4:-}"

    if ! has_op_cli; then
        die EX_UNAVAILABLE "1Password CLI (op) not found"
    fi

    local args=("item" "create" "--category" "Secure Note" "--title" "$item_name" "$field_name=$value")
    if [[ -n "$vault_name" ]]; then
        args+=("--vault" "$vault_name")
    fi

    op "${args[@]}" >/dev/null 2>&1
}

# Get secret from macOS Keychain
# Usage: get_secret_keychain "service" "account"
get_secret_keychain() {
    local service="$1"
    local account="$2"

    if ! has_keychain; then
        die EX_UNAVAILABLE "macOS security command not found"
    fi

    security find-generic-password -s "$service" -a "$account" -w 2>/dev/null
}

# Store secret in macOS Keychain
# Usage: store_secret_keychain "service" "account" "value"
store_secret_keychain() {
    local service="$1"
    local account="$2"
    local value="$3"

    if ! has_keychain; then
        die EX_UNAVAILABLE "macOS security command not found"
    fi

    security add-generic-password -s "$service" -a "$account" -w "$value" -U 2>/dev/null
}

# Generic secret getter - tries 1Password first, then Keychain, then env
# Usage: get_secret "secret-name"
get_secret() {
    local name="$1"
    local value=""

    # Try 1Password first (if signed in)
    if has_op_cli && op account list >/dev/null 2>&1; then
        value=$(get_secret_op "Workstation Secrets" "$name" 2>/dev/null || true)
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Try Keychain
    value=$(get_secret_keychain "workstation-framework" "$name" 2>/dev/null || true)
    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi

    # Try environment variable (uppercase with underscores)
    local env_var
    env_var=$(echo "$name" | tr '[:lower:]-' '[:upper:]_')
    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return 0
    fi

    return 1
}

# Generic secret setter - stores in Keychain (always available on macOS)
# Usage: store_secret "secret-name" "value"
store_secret() {
    local name="$1"
    local value="$2"

    store_secret_keychain "workstation-framework" "$name" "$value"
}

# Delete secret from Keychain
# Usage: delete_secret "secret-name"
delete_secret() {
    local name="$1"

    if has_keychain; then
        security delete-generic-password -s "workstation-framework" -a "$name" 2>/dev/null || true
    fi
}

# List all stored secrets
list_secrets() {
    if has_keychain; then
        security find-generic-password -s "workstation-framework" 2>/dev/null |
            grep "acct=" | sed -E 's/.*acct="([^"]+)".*/\1/'
    fi
}

export SECRETS_LOADED
