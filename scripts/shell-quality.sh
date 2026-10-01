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

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

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
                local version_file
                version_file="$(dirname "$0")/../VERSION"
                if [[ -f "$version_file" ]]; then
                    echo "$(basename "$0") $(cat "$version_file")"
                else
                    echo "$(basename "$0") unknown (VERSION file not found)" >&2
                    exit 1
                fi
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ $# -ne 1 ]]; then
        usage >&2
        die "$EX_USAGE" "Exactly one script argument required"
    fi
}

main() {
    parse_args "$@"

    readonly SCRIPT="$1"

    if [[ ! -f "$SCRIPT" ]]; then
        die "$EX_NOINPUT" "File not found: $SCRIPT"
    fi

    echo
    echo "========================================="
    echo " Shell Quality Report"
    echo "========================================="
    echo

    FAILED=0
    MISSING_TOOL=false

    echo "Checking Bash syntax..."
    if ! bash -n "$SCRIPT"; then
        echo "✗ Bash syntax check failed"
        FAILED=1
    else
        echo "✓ Bash syntax OK"
    fi

    if [[ "${ENABLE_SHELLCHECK:-true}" == "true" ]]; then
        echo
        if ! command -v shellcheck >/dev/null 2>&1; then
            # An absent tool is an incomplete environment, not a code-quality
            # finding. Reported distinctly so it is never read as a lint
            # failure; FAILED is left alone so the verdict is not corrupted.
            log_warn "shellcheck not installed - skipping ShellCheck checks"
            MISSING_TOOL=true
        else
            echo "Checking ShellCheck..."
            # -x follows sourced files, matching the Makefile and CI invocation.
            # SC1091 ("Not following") is excluded because every utility sources
            # via the ${SCRIPT_DIR} shell variable, which ShellCheck cannot
            # resolve statically, so the notice is unavoidable for a single-file
            # check and is not a defect in the file being checked. See
            # CODE_REVIEW_CHECKLIST.md: an SC1091 suppression needs a reason.
            if ! shellcheck -x --exclude=SC1091 "$SCRIPT"; then
                echo "✗ ShellCheck found issues"
                FAILED=1
            else
                echo "✓ ShellCheck passed"
            fi
        fi
    else
        echo
        echo "Skipping ShellCheck (ENABLE_SHELLCHECK=false)"
    fi

    if [[ "${ENABLE_SHFMT:-true}" == "true" ]]; then
        echo
        if ! command -v shfmt >/dev/null 2>&1; then
            log_warn "shfmt not installed - skipping formatting check"
            MISSING_TOOL=true
        else
            echo "Checking formatting..."
            if ! shfmt -d -i 4 -ci "$SCRIPT" >/dev/null; then
                echo "✗ Formatting issues found (run 'shfmt -w -i 4 -ci' to fix)"
                FAILED=1
            else
                echo "✓ Formatting OK"
            fi
        fi
    else
        echo
        echo "Skipping formatting check (ENABLE_SHFMT=false)"
    fi

    echo
    echo "========================================="
    if [[ $MISSING_TOOL == true ]]; then
        # Non-zero: the environment could not be fully validated. Distinct
        # from a lint failure so the two are never confused.
        echo "✗ Quality checks incomplete: required tool not installed"
        echo "========================================="
        exit 69
    elif [[ $FAILED -eq 0 ]]; then
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
