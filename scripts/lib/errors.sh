#!/usr/bin/env bash

###############################################################################
# Library: errors.sh
# Version: see VERSION file
#
# Purpose:
#   Standardized error codes and error handling helpers for the
#   Developer Workstation Framework.
#
# Based on sysexits.h conventions where applicable.
###############################################################################

# Exit codes
# shellcheck disable=SC2034
readonly EX_OK=0           # Successful termination
readonly EX_USAGE=64       # Command line usage error
readonly EX_DATAERR=65     # Data format error
readonly EX_NOINPUT=66     # Cannot open input
readonly EX_NOUSER=67      # Addressee unknown
readonly EX_NOHOST=68      # Host name unknown
readonly EX_UNAVAILABLE=69 # Service unavailable
readonly EX_SOFTWARE=70    # Internal software error
readonly EX_OSERR=71       # System error (e.g., can't fork)
readonly EX_OSFILE=72      # Critical OS file missing
readonly EX_CANTCREAT=73   # Can't create (user) output file
readonly EX_IOERR=74       # Input/output error
readonly EX_TEMPFAIL=75    # Temp failure; user invited to retry
readonly EX_PROTOCOL=76    # Remote error in protocol
readonly EX_NOPERM=77      # Permission denied
readonly EX_CONFIG=78      # Configuration error
readonly EX_TIMEOUT=79     # Operation timed out

# Error messages
error_message() {
    local code="$1"
    case $code in
        "$EX_USAGE") echo "Usage error" ;;
        "$EX_DATAERR") echo "Data format error" ;;
        "$EX_NOINPUT") echo "Cannot open input" ;;
        "$EX_NOUSER") echo "User unknown" ;;
        "$EX_NOHOST") echo "Host unknown" ;;
        "$EX_UNAVAILABLE") echo "Service unavailable" ;;
        "$EX_SOFTWARE") echo "Internal software error" ;;
        "$EX_OSERR") echo "System error" ;;
        "$EX_OSFILE") echo "Critical OS file missing" ;;
        "$EX_CANTCREAT") echo "Cannot create output file" ;;
        "$EX_IOERR") echo "I/O error" ;;
        "$EX_TEMPFAIL") echo "Temporary failure, please retry" ;;
        "$EX_PROTOCOL") echo "Protocol error" ;;
        "$EX_NOPERM") echo "Permission denied" ;;
        "$EX_CONFIG") echo "Configuration error" ;;
        "$EX_TIMEOUT") echo "Operation timed out" ;;
        *) echo "Unknown error (code: $code)" ;;
    esac
}

# Exit with error code and optional message
die() {
    local code="${1:-$EX_SOFTWARE}"
    local msg="${2:-$(error_message "$code")}"
    echo "Error ($code): $msg" >&2
    exit "$code"
}

# Assert condition, exit with code if false
assert() {
    local condition="$1"
    local code="${2:-$EX_SOFTWARE}"
    local msg="${3:-Assertion failed}"

    if ! eval "$condition"; then
        die "$code" "$msg"
    fi
}

# Require command to be available
require_command() {
    local cmd="$1"
    local code="${2:-$EX_UNAVAILABLE}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "$code" "Required command not found: $cmd"
    fi
}

# Require file to exist and be readable
require_file() {
    local file="$1"
    local code="${2:-$EX_NOINPUT}"

    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        die "$code" "Required file not found or not readable: $file"
    fi
}

# Require directory to exist
require_directory() {
    local dir="$1"
    local code="${2:-$EX_NOINPUT}"

    if [[ ! -d "$dir" ]]; then
        die "$code" "Required directory not found: $dir"
    fi
}

# Require environment variable to be set
require_var() {
    local var="$1"
    local code="${2:-$EX_CONFIG}"

    if [[ -z "${!var:-}" ]]; then
        die "$code" "Required environment variable not set: $var"
    fi
}

# Try to run command with retries
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    shift 2
    local cmd=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "${cmd[@]}"; then
            return 0
        fi
        if [[ $attempt -lt $max_attempts ]]; then
            sleep "$delay"
        fi
        ((attempt++))
    done

    return 1
}
