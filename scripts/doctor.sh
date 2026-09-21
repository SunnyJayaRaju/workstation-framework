#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: doctor.sh
# Version: see VERSION file
#
# Purpose:
#   Verify that the Developer Workstation Framework and its dependencies
#   are correctly installed.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

LIB_DIR="${SCRIPT_DIR}/lib"
readonly LIB_DIR

# shellcheck source=lib/errors.sh
source "${LIB_DIR}/errors.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/colors.sh"
# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/logging.sh"
# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/checks.sh"
# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/filesystem.sh"

# Failure counter
FAILURES=0

# Wrapper for log_fail that increments failure counter
log_fail_tracked() {
    log_fail "$1"
    ((FAILURES++))
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Verify that the Developer Workstation Framework and its dependencies
are correctly installed.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit
  -i, --installed  Check installed utilities (default: check source)
EOF
}

parse_args() {
    CHECK_INSTALLED=false
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
            -i | --installed)
                CHECK_INSTALLED=true
                shift
                ;;
            *)
                die EX_USAGE "Unknown option: $1"
                ;;
        esac
    done
}

check_utilities() {
    local base_dir="$1"
    local label="$2"

    log_info "Checking framework utilities (${label})..."

    # List of utilities that are installed (install.sh is the installer, not installed)
    local utilities=(
        backup.sh
        check-project.sh
        repo-clean.sh
        doctor.sh
        restore.sh
        shell-quality.sh
        sync.sh
        uninstall.sh
        update.sh
    )

    # List of utilities that should be executable from installed location
    # (update.sh requires install.sh which is not installed; install.sh is not installed)
    local executable_utilities=(
        backup.sh
        check-project.sh
        repo-clean.sh
        doctor.sh
        restore.sh
        shell-quality.sh
        sync.sh
        uninstall.sh
    )

    for utility in "${utilities[@]}"; do
        if file_exists "${base_dir}/${utility}"; then
            log_pass "${utility}"
        else
            log_fail_tracked "${utility}"
        fi
    done

    # Verify library directory
    if directory_exists "${base_dir}/lib"; then
        log_pass "lib/ directory"
    else
        log_fail_tracked "lib/ directory"
    fi

    # If checking installed, also verify they execute without error
    if [[ "$CHECK_INSTALLED" == "true" ]]; then
        log_info "Verifying installed utilities execute correctly..."
        for utility in "${executable_utilities[@]}"; do
            if [[ -x "${base_dir}/${utility}" ]]; then
                # Run with --version to verify it works
                if "${base_dir}/${utility}" --version >/dev/null 2>&1; then
                    log_pass "${utility} executes"
                else
                    log_fail_tracked "${utility} execution failed"
                fi
            else
                log_fail_tracked "${utility} not executable"
            fi
        done
    fi
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Doctor"
    echo "========================================="
    echo

    log_info "Checking framework structure..."

    if directory_exists "${SCRIPT_DIR}/lib"; then
        log_pass "scripts/lib found"
    else
        log_fail_tracked "scripts/lib missing"
    fi

    if directory_exists "${SCRIPT_DIR}"; then
        log_pass "scripts directory found"
    else
        log_fail_tracked "scripts directory missing"
    fi

    echo

    log_info "Checking required commands..."

    for command in git bash shellcheck shfmt; do
        if command -v "${command}" >/dev/null 2>&1; then
            log_pass "${command} installed"
        else
            log_fail_tracked "${command} missing"
        fi
    done

    echo

    check_utilities "${SCRIPT_DIR}" "source"

    # If installed, check installation directory
    if [[ "$CHECK_INSTALLED" == "true" ]]; then
        # Try to load config to get INSTALL_DIR
        if [[ -f "${SCRIPT_DIR}/lib/config.sh" ]]; then
            # shellcheck source=lib/config.sh
            source "${SCRIPT_DIR}/lib/config.sh"
            load_config
            if [[ -n "${INSTALL_DIR:-}" ]] && directory_exists "${INSTALL_DIR}"; then
                echo
                check_utilities "${INSTALL_DIR}" "installed"
            fi
        fi
    fi

    echo
    echo "Doctor completed."

    if [[ ${FAILURES} -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
