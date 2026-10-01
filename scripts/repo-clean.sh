#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: repo-clean.sh
# Version: see VERSION file
#
# Purpose:
#   Remove temporary files generated during development without
#   affecting tracked project files.
#
# Operation:
#   Scans the repository root (the parent directory of this script's location)
#   for temporary files matching patterns: *.orig, *~, .DS_Store
#   Excludes version control directories: .git, .hg, .svn
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Default scan root: the parent of this script's directory. For a source-tree
# checkout that is the repository; for an INSTALLED copy (e.g. ~/.local/bin)
# it is the install prefix, which is NOT a project. Such runs are refused
# below unless the caller names a root explicitly.
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEFAULT_ROOT

ROOT_OVERRIDE=""

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/colors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/errors.sh"

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

DRY_RUN=false
VERBOSE=false
removed=0
failed=0

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Remove temporary development artifacts safely.

Options:
  -n, --dry-run       Show what would be deleted without deleting
  -v, --verbose       Show each file being deleted
  -r, --root <path>   Scan <path> instead of the script's parent directory
  -h, --help          Show this help and exit
  -V, --version       Show version and exit

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
            -r | --root)
                if [[ -z "${2:-}" ]]; then
                    die EX_USAGE "--root requires a path argument"
                fi
                ROOT_OVERRIDE="$2"
                shift 2
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

# Removes each file. Continues past failures so one unwritable file cannot
# block cleanup of everything else, but reports an honest tally: a single
# "succeeded failed" line the caller turns into the exit status.
# Prints "<removed> <failed>" on stdout.
delete_files() {
    local files=("$@")
    local removed=0
    local failed=0

    for file in "${files[@]}"; do
        # stderr, not stdout: stdout is captured by the caller via $(...) to
        # obtain the tally, so a stdout log here would corrupt the count.
        if [[ "$VERBOSE" == true ]]; then
            echo "Removing: $file" >&2
        fi

        if [[ "$DRY_RUN" == true ]]; then
            removed=$((removed + 1))
            continue
        fi

        if rm -f "$file"; then
            removed=$((removed + 1))
        else
            failed=$((failed + 1))
            log_fail "Could not remove: $file"
        fi
    done

    echo "${removed} ${failed}"
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Repo Cleanup"
    echo "========================================="
    echo

    # This tool deletes files recursively. Only ever point it at something
    # that is recognisably a project, so an installed copy cannot be tricked
    # into treating its install prefix (e.g. ~/.local) as a scratch tree.
    if [[ "${ENABLE_CLEANUP:-true}" != "true" ]]; then
        log_info "Cleanup disabled by configuration (ENABLE_CLEANUP); nothing to do."
        return 0
    fi

    local project_root
    project_root="${ROOT_OVERRIDE:-$DEFAULT_ROOT}"

    if [[ ! -d "$project_root" ]]; then
        die EX_NOINPUT "Not a directory: ${project_root}"
    fi

    if [[ ! -d "${project_root}/.git" ]]; then
        log_fail "Refusing to run: ${project_root} is not a project (no .git directory)."
        die EX_USAGE "Pass --root <path> to target a specific git project."
    fi

    PROJECT_ROOT="$(cd "$project_root" && pwd)"
    readonly PROJECT_ROOT

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run mode - no files will be deleted"
    fi

    log_info "Scanning for temporary files in ${PROJECT_ROOT}..."

    # Use while read loop for compatibility with bash 3.2 (macOS default)
    temp_files=()
    while IFS= read -r line; do
        temp_files+=("$line")
    done < <(find_temp_files "$PROJECT_ROOT")

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
        tally=$(delete_files "${temp_files[@]}")
        removed="${tally%% *}"
        failed="${tally##* }"

        log_info "${removed} removed, ${failed} failed"
    fi

    echo

    if [[ "$failed" -gt 0 ]]; then
        log_fail "Cleanup finished with errors."
        exit 1
    fi

    log_pass "Cleanup completed successfully."
}

main "$@"
