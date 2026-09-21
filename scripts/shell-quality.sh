#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: shell-quality.sh
# Version: see VERSION file
#
# Purpose:
#   Run quality checks against a shell script.
###############################################################################

# shellcheck source=lib/config.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
load_config

# shellcheck source=lib/errors.sh
source "${SCRIPT_DIR}/lib/errors.sh"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <shell-script>

Run quality checks against a shell script.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Checks performed:
  - Bash syntax validation (bash -n)
  - ShellCheck static analysis
  - shfmt formatting verification

Environment Variables:
  ENABLE_SHELLCHECK  Enable/disable ShellCheck (default: true)
  ENABLE_SHFMT       Enable/disable shfmt check (default: true)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h | --help)
                usage
                exit 0
                ;;
            -v | --version)
                echo "$(basename "$0") $(cat "$(dirname "$0")/../VERSION")"
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ $# -ne 1 ]]; then
        usage >&2
        die EX_USAGE "Exactly one script argument required"
    fi
}

main() {
    parse_args "$@"

    readonly SCRIPT="$1"

    if [[ ! -f "$SCRIPT" ]]; then
        die EX_NOINPUT "File not found: $SCRIPT"
    fi

    echo
    echo "========================================="
    echo " Shell Quality Report"
    echo "========================================="
    echo

    FAILED=0

    echo "Checking Bash syntax..."
    if ! bash -n "$SCRIPT"; then
        echo "✗ Bash syntax check failed"
        FAILED=1
    else
        echo "✓ Bash syntax OK"
    fi

    if [[ "${ENABLE_SHELLCHECK:-true}" == "true" ]]; then
        echo
        echo "Checking ShellCheck..."
        if ! shellcheck "$SCRIPT"; then
            echo "✗ ShellCheck found issues"
            FAILED=1
        else
            echo "✓ ShellCheck passed"
        fi
    else
        echo
        echo "Skipping ShellCheck (ENABLE_SHELLCHECK=false)"
    fi

    if [[ "${ENABLE_SHFMT:-true}" == "true" ]]; then
        echo
        echo "Checking formatting..."
        if ! shfmt -d -i 4 -ci "$SCRIPT" >/dev/null; then
            echo "✗ Formatting issues found (run 'shfmt -w -i 4 -ci' to fix)"
            FAILED=1
        else
            echo "✓ Formatting OK"
        fi
    else
        echo
        echo "Skipping formatting check (ENABLE_SHFMT=false)"
    fi

    echo
    echo "========================================="
    if [[ $FAILED -eq 0 ]]; then
        echo "✓ All quality checks passed"
        echo "========================================="
        exit 0
    else
        echo "✗ Quality checks failed"
        echo "========================================="
        exit 1
    fi
}

main "$@"
