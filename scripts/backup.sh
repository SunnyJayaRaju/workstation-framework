#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: backup.sh
# Version: see VERSION file
#
# Purpose:
#   Create timestamped backups of configured configuration files.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

load_config

# shellcheck source=lib/errors.sh
source "${SCRIPT_DIR}/lib/errors.sh"

require_var BACKUP_DIR "$EX_CONFIG"

readonly BACKUP_DIR

# Configurable backup sources - can be overridden via BACKUP_SOURCES env var.
# Parsed below, once the shared helper has been sourced.

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly TIMESTAMP

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source-path=SCRIPTDIR/lib
source "${SCRIPT_DIR}/lib/filesystem.sh"

# shellcheck source=lib/backup_paths.sh
source "${SCRIPT_DIR}/lib/backup_paths.sh"

parse_backup_sources

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Create timestamped backups of configured configuration files.

Options:
  -h, --help       Show this help and exit
  -v, --version    Show version and exit

Environment Variables:
  BACKUP_DIR       Backup destination directory (required)
  BACKUP_SOURCES   Space-separated list of files to backup (default: .zshrc .gitconfig .ssh/config)
  LOG_LEVEL        Log verbosity (0=error, 1=warn, 2=info, 3=debug)
  LOG_FORMAT       Log format (simple, json, timestamped)

Examples:
  BACKUP_DIR=~/backups $0
  BACKUP_DIR=/tmp/backups BACKUP_SOURCES=".zshrc .vimrc" $0
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
                die "$EX_USAGE" "Unknown option: $1"
                ;;
        esac
    done
}

backup_file() {
    local source="$1"
    local dest_dir="$2"
    local timestamp="$3"

    source="$(expand_source_path "$source")"

    local key
    key="$(backup_key "$source")"
    local destination="${dest_dir}/${key}_${timestamp}"

    if [[ ! -f "$source" ]]; then
        log_fail "Source file not found: ${source}"
        return 1
    fi

    # `install -m 600` creates the destination with restrictive permissions
    # and writes the content in one step. The previous `cp -p` + `chmod 600`
    # left a window where a copy of ~/.ssh/config or ~/.gitconfig existed at
    # the source's (often 644) mode.
    if ! install -m 600 "$source" "$destination"; then
        log_fail "Failed to back up: ${source}"
        return 1
    fi

    log_pass "Backed up: ${source} -> ${destination}"

    # Recorded for the run manifest. Written to a plain array and flushed
    # once, at the end, only if every source succeeded.
    MANIFEST_ENTRIES+=("$(basename "$destination")|$(json_escape "$source")|$(sha256_of "$destination")")
}

# Record what this run wrote, so restore.sh can tell an intact backup from a
# corrupted one before it overwrites anything.
#
# Written only after the whole run succeeded. A run that failed partway must
# not leave a manifest asserting success for files it never reached.
write_manifest() {
    local dest_dir="$1"
    local timestamp="$2"

    local manifest="${dest_dir}/manifest_${timestamp}.json"
    local tmp="${manifest}.tmp.$$"
    local entry

    {
        printf '{"version":1,"timestamp":"%s","entries":[\n' "$(json_escape "$timestamp")"
        local first=1
        for entry in "${MANIFEST_ENTRIES[@]}"; do
            [[ $first -eq 1 ]] || printf ',\n'
            first=0
            local backup_name="${entry%%|*}"
            local rest="${entry#*|}"
            local src="${rest%%|*}"
            local hash="${rest##*|}"
            printf '{"backup":"%s","source":"%s","sha256":"%s"}' \
                "$(json_escape "$backup_name")" "$src" "$(json_escape "$hash")"
        done
        printf '\n]}\n'
    } >"$tmp" || {
        rm -f "$tmp"
        log_warn "Could not write backup manifest; restores will not be verified."
        return 1
    }

    # 600: the manifest names the user's real dotfile paths. Written via a
    # temp file and moved into place so a reader never sees a partial manifest.
    chmod 600 "$tmp"
    mv -f "$tmp" "$manifest"
    log_pass "Manifest written: ${manifest}"
}

# BACKUP_SOURCES is space-separated, which cannot express a path containing a
# space. Newline-separated listings are supported as an alternative; within the
# space-separated form, warn when a token is missing but token+next exists,
# which is the signature of one path having been split in two.
warn_if_split_source() {
    local i last
    last=$((${#BACKUP_SOURCES[@]} - 1))

    for ((i = 0; i < last; i++)); do
        local token="${BACKUP_SOURCES[$i]}"
        local pair="${token} ${BACKUP_SOURCES[$((i + 1))]}"

        if [[ ! -f "$(expand_source_path "$token")" ]] &&
            [[ -f "$(expand_source_path "$pair")" ]]; then
            log_warn "BACKUP_SOURCES entry '${token}' does not exist, but '${pair}' does."
            log_warn "This entry looks like a path containing a space that was split."
            log_warn "List sources one per line (newline-separated) to include such paths."
        fi
    done
}

main() {
    parse_args "$@"

    echo
    echo "========================================="
    echo " Developer Workstation Backup"
    echo "========================================="
    echo

    if [[ "${ENABLE_BACKUP:-true}" != "true" ]]; then
        log_info "Backup disabled by configuration (ENABLE_BACKUP); nothing to do."
        return 0
    fi

    log_info "Preparing backup..."

    ensure_directory "${BACKUP_DIR}"

    # The backup files are written 600, but the directory itself was left at
    # whatever umask produced -- 755 here -- which lets anyone list the names of
    # the user's config files and the timestamps of every backup. tighten it, and
    # tighten an existing store too, since ensure_directory only creates.
    #
    # Scoped to BACKUP_DIR on purpose: ensure_directory's default is unchanged so
    # INSTALL_DIR and the other callers are unaffected.
    chmod 700 "${BACKUP_DIR}" 2>/dev/null || true

    warn_if_split_source

    local failed=0
    local source
    MANIFEST_ENTRIES=()
    for source in "${BACKUP_SOURCES[@]}"; do
        if ! backup_file "$source" "${BACKUP_DIR}" "${TIMESTAMP}"; then
            failed=1
        fi
    done

    echo
    if [[ $failed -eq 0 ]]; then
        # Only now, with every source confirmed on disk.
        write_manifest "${BACKUP_DIR}" "${TIMESTAMP}" || true
        log_pass "Backup completed successfully."
    else
        log_fail "Backup completed with errors."
        log_info "No manifest written for this run; these backups cannot be integrity-checked."
        exit 1
    fi
}

main "$@"
