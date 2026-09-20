#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: repo-clean.sh
# Version: 3.1.0
#
# Purpose:
#   Remove temporary files generated during development without
#   affecting tracked project files.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

DRY_RUN=false
VERBOSE=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Remove temporary development artifacts safely.

Options:
  -n, --dry-run    Show what would be deleted without deleting
  -v, --verbose    Show each file being deleted
  -h, --help       Show this help and exit
  -V, --version    Show version and exit

Targets (only within project root):
  *.orig           Merge conflict backup files
  *~               Editor backup files
  .DS_Store        macOS metadata files
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n | --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v | --verbose)
                VERBOSE=true
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            -V | --version)
                echo "repo-clean.sh 3.1.0"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 64
                ;;
        esac
    done
}

find_temp_files() {
    local root="$1"

    # Only search in project root, not .git or other VCS dirs
    find "$root" \
        -type f \
        \( -name '*.orig' -o -name '*~' -o -name '.DS_Store' \) \
        -not -path '*/.git/*' \
        -not -path '*/.hg/*' \
        -not -path '*/.svn/*' \
        -print
}

delete_files() {
    local files=("$@")
    local count=0

    for file in "${files[@]}"; do
        if [[ "$VERBOSE" == true ]]; then
            echo "Removing: $file"
        fi
        if [[ "$DRY_RUN" == false ]]; then
            rm -f "$file"
        fi
        ((count++))
    done

    echo "$count"
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Repo Cleanup"
    echo "========================================="
    echo

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run mode - no files will be deleted"
    fi

    log_info "Scanning for temporary files in ${PROJECT_ROOT}..."

    mapfile -t temp_files < <(find_temp_files "$PROJECT_ROOT")

    if [[ ${#temp_files[@]} -eq 0 ]]; then
        log_info "No temporary files found."
        echo
        log_pass "Cleanup completed successfully."
        return 0
    fi

    log_info "Found ${#temp_files[@]} temporary file(s)"

    if [[ "$DRY_RUN" == true ]]; then
        for file in "${temp_files[@]}"; do
            echo "  Would remove: $file"
        done
    else
        log_info "Removing temporary files..."
        deleted=$(delete_files "${temp_files[@]}")
        log_pass "Removed $deleted file(s)"
    fi

    echo
    log_pass "Cleanup completed successfully."
}

main "$@"
