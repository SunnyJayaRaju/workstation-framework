#!/usr/bin/env bash

###############################################################################
# Script: doctor.sh
# Version: 2.0.0
#
# Purpose:
#   Verify that the Developer Workstation Framework and its dependencies
#   are correctly installed.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

LIB_DIR="${SCRIPT_DIR}/lib"
readonly LIB_DIR

# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/colors.sh"
# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/logging.sh"
# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/checks.sh"
# shellcheck source-path=SCRIPTDIR/lib
source "${LIB_DIR}/filesystem.sh"

echo
echo "========================================="
echo " Developer Workstation Doctor"
echo "========================================="
echo

log_info "Checking framework structure..."

if directory_exists "${SCRIPT_DIR}/lib"
then
    log_pass "scripts/lib found"
else
    log_fail "scripts/lib missing"
fi

if directory_exists "${SCRIPT_DIR}"
then
    log_pass "scripts directory found"
else
    log_fail "scripts directory missing"
fi

echo

log_info "Checking required commands..."

for command in git bash shellcheck shfmt eza
do
    if command -v "${command}" >/dev/null 2>&1
    then
        log_pass "${command} installed"
    else
        log_fail "${command} missing"
    fi
done

echo

log_info "Checking framework utilities..."

for utility in \
    backup.sh \
    bootstrap.sh \
    check-project.sh \
    shell-quality.sh
do
    if file_exists "${SCRIPT_DIR}/${utility}"
    then
        log_pass "${utility}"
    else
        log_fail "${utility}"
    fi
done

echo
echo "Doctor completed."
