#!/usr/bin/env bash

###############################################################################
# Library: logging.sh
# Version: see VERSION file
#
# Purpose:
#   Shared logging helpers for the
#   Developer Workstation Framework.
#
# Usage:
#   source scripts/lib/logging.sh
#   log_info "message"
#   log_warn "message"
#   log_error "message"
#   log_debug "message"
#   log_pass "message"
#   log_fail "message"
###############################################################################

# Log levels (higher = more verbose)
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Default log level
: "${LOG_LEVEL:=$LOG_LEVEL_INFO}"

# Log format: simple, json, timestamped
: "${LOG_FORMAT:=simple}"

# Source colors if not already loaded
if [[ -z "${COLOR_RESET:-}" ]]; then
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_RED="\033[31m"
    readonly COLOR_GREEN="\033[32m"
    readonly COLOR_YELLOW="\033[33m"
    readonly COLOR_BLUE="\033[34m"
    readonly COLOR_BOLD="\033[1m"
fi

# Check if output is a terminal for color support
is_tty() {
    [[ -t 1 ]]
}

# Format timestamp
log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Core logging function
_log() {
    local level="$1"
    local level_name="$2"
    local color="$3"
    local message="$4"

    # Check if we should log this level
    if [[ $LOG_LEVEL -lt $level ]]; then
        return 0
    fi

    local timestamp
    timestamp="$(log_timestamp)"

    local output
    case "$LOG_FORMAT" in
        json)
            output="$(printf '{"timestamp":"%s","level":"%s","message":"%s"}' "$timestamp" "$level_name" "$message")"
            ;;
        timestamped)
            output="[$timestamp] [$level_name] $message"
            ;;
        simple | *)
            if is_tty && [[ -n "$color" ]]; then
                output="${color}${level_name}${COLOR_RESET} $message"
            else
                output="[$level_name] $message"
            fi
            ;;
    esac

    printf "%s\n" "$output"
}

# Public logging functions
log_error() {
    _log $LOG_LEVEL_ERROR "ERROR" "$COLOR_RED" "$1" >&2
}

log_warn() {
    _log $LOG_LEVEL_WARN "WARN" "$COLOR_YELLOW" "$1"
}

log_info() {
    _log $LOG_LEVEL_INFO "INFO" "$COLOR_BLUE" "$1"
}

log_debug() {
    _log $LOG_LEVEL_DEBUG "DEBUG" "$COLOR_BOLD" "$1"
}

log_pass() {
    # Pass messages always show at INFO level
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        if is_tty; then
            printf "%s %s\n" "${COLOR_GREEN}✓${COLOR_RESET}" "$1"
        else
            printf "[PASS] %s\n" "$1"
        fi
    fi
}

log_fail() {
    # Fail messages always show at ERROR level
    if is_tty; then
        printf "%s %s\n" "${COLOR_RED}✗${COLOR_RESET}" "$1" >&2
    else
        printf "[FAIL] %s\n" "$1" >&2
    fi
}

# Backward compatibility aliases (exported for scripts that may reference them)
export PASS_MARK="✓"
export FAIL_MARK="✗"
export INFO_MARK="ℹ"
