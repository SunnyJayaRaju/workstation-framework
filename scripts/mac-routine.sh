#!/usr/bin/env bash

###############################################################################
# Script: mac-routine.sh
# Version: see VERSION file
#
# Purpose:
#   Run the weekly maintenance routine in a fixed order and PROVE, between
#   every step, that nothing has taken root ownership of Homebrew Ruby or
#   changed the gem version.
#
#   Order: topgrade -> mo clean -> brew doctor -> brew cleanup
#
# WHY THIS EXISTS
#   On 2026-09-16 a RubyGems 4.0.21 tree was written into
#   /opt/homebrew/lib/ruby/site_ruby/ as root (Homebrew ships 4.0.20). The
#   root-owned files then blocked `brew link` and `brew cleanup`, and the
#   routine could not finish. Which process issued it is still unproven, so
#   this wrapper does not guess: it measures before and after every step and
#   stops at the first step that changes the picture.
#
# NEVER
#   - calls sudo. The fix commands it prints are for the user to run.
#   - hangs on a prompt. topgrade runs --no-ask-retry, and the Containers step
#     is disabled when no container runtime is running. The flag set was read
#     out of `topgrade --help` on 2026-10-10 (topgrade 17.12.3), re-verified
#     against 17.16.0 on 2026-11-11, and pinned by a test.
#   - deletes anything.
#   - upgrades the OS. `--disable system` keeps the macOS system-update step
#     out of a maintenance run: a recorded run had that step auto-consent
#     through --yes to downloading a full macOS upgrade and prompt for a
#     password mid-routine. An OS upgrade is a deliberate decision, not part
#     of this routine.
#
# Usage: mac-routine [--dry-run] [--help]
###############################################################################

set -uo pipefail

readonly PROGRAM_NAME="${0##*/}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RGH_LIB="${RGH_LIB:-${SCRIPT_DIR}/lib/ruby_gem_health.sh}"
if [ ! -r "$RGH_LIB" ]; then
    printf 'mac-routine: cannot read %s\n' "$RGH_LIB" >&2
    exit 2
fi
# shellcheck source=lib/ruby_gem_health.sh
source "$RGH_LIB"

usage() {
    cat <<EOF
Usage: ${PROGRAM_NAME} [OPTIONS]

Run topgrade, mo clean, brew doctor and brew cleanup in order, measuring
root-owned files and the gem version between every step. Stops at the first
step that changes either. Never uses sudo. Never deletes anything.

Options:
  --dry-run   Measure only. Run every check, run no maintenance command.
  -h, --help  Show this text.

Environment:
  RGH_HOMEBREW_ROOT   Override the Homebrew root (default /opt/homebrew)
  RGH_GEM_HOME        Override the user gem home (default ~/.gem)
  RGH_LIB             Override the path to lib/ruby_gem_health.sh

Exit codes:
  0   every step ran and the final health report has no FAIL line (a WARN is still 0)
  1   the final health report found damage - see its FAIL lines
  2   usage error, or the health library is unreadable
  3   a step changed ownership or broke gem parity; the routine aborted there
EOF
}

DRY_RUN=0
# PREV_* are forced empty here so an ambient exported variable of the same
# name cannot seed drift_check with garbage: measure() seeds them from the
# baseline on first use regardless.
PREV_HB='' PREV_GEM='' PREV_GEMV=''
case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    '') ;;
    *)
        printf 'Unknown option: %s\nTry %s --help\n' "$1" "$PROGRAM_NAME" >&2
        exit 2
        ;;
esac
[ "$#" -le 1 ] || {
    printf 'Unexpected argument: %s\nTry %s --help\n' "$2" "$PROGRAM_NAME" >&2
    exit 2
}

# ---- measurement ----------------------------------------------------------
#
# One snapshot = the two numbers that detect the 2026-09-16 damage. Taken
# before the first step and again after every step.

measure() {
    ROOT_HB="$(rgh_root_owned_count "$RGH_HOMEBREW_ROOT")"
    ROOT_GEM="$(rgh_root_owned_count "$RGH_GEM_HOME")"
    GEMV="$(rgh_active_gem_version)"
    [ -n "$GEMV" ] || GEMV='none'
    if [ -z "${PREV_HB:-}" ]; then
        PREV_HB="$ROOT_HB"
        PREV_GEM="$ROOT_GEM"
        PREV_GEMV="$GEMV"
    fi
}

show() {
    printf '    %-22s root-owned: %s=%s ~/.gem=%s   gem -v: %s\n' \
        "$1" "$RGH_HOMEBREW_ROOT" "$ROOT_HB" "$ROOT_GEM" "$GEMV"
}

accept() {
    PREV_HB="$ROOT_HB"
    PREV_GEM="$ROOT_GEM"
    PREV_GEMV="$GEMV"
}

# Stop the routine if this step changed ownership or the gem version. The two
# are reported separately because they have different causes: a new root-owned
# file is a privilege problem, a changed gem -v is a RubyGems override problem.
drift_check() {
    local where="$1" drifted=0 p

    if [ "$ROOT_HB" != "$PREV_HB" ] || [ "$ROOT_GEM" != "$PREV_GEM" ]; then
        drifted=1
        printf '\nSTOPPED after step: %s\n' "$where"
        printf '  root-owned entries changed: %s %s -> %s, ~/.gem %s -> %s\n' \
            "$RGH_HOMEBREW_ROOT" "$PREV_HB" "$ROOT_HB" "$PREV_GEM" "$ROOT_GEM"
        printf '  root-owned paths now present:\n'
        while IFS= read -r p; do
            [ -n "$p" ] && printf '    %s\n' "$p"
        done < <(rgh_root_owned_list "$RGH_HOMEBREW_ROOT" "$RGH_GEM_HOME" | head -10)
        printf '  fix (needs your password, run it yourself):\n'
        # shellcheck disable=SC2016  # $(whoami) is printed for the user to run, not expanded here
        printf '    sudo find %s -user root -exec chown -h "$(whoami)":admin {} +\n' "$RGH_HOMEBREW_ROOT"
    fi

    if [ "$GEMV" != "$PREV_GEMV" ]; then
        # A changed gem -v has two causes with different verdicts. A Ruby keg
        # upgrade moves BOTH the active and the shipped version - parity
        # holds. A site_ruby override moves only the active one - parity
        # breaks, and that is the 2026-09-16 damage. Parity of the new state
        # decides, so a legitimate upgrade does not abort the routine.
        if parity="$(rgh_check_gem_version_parity)"; then
            printf '\nNOTE after step: %s\n' "$where"
            printf '  gem -v changed: %s -> %s\n' "$PREV_GEMV" "$GEMV"
            printf '%s\n' "$parity"
            printf '  the active version matches what the active Ruby ships:\n'
            printf '  a Ruby keg upgrade, not an override. Continuing; the final\n'
            printf '  health report decides whether the new keg left anything dangling.\n'
        else
            drifted=1
            printf '\nSTOPPED after step: %s\n' "$where"
            printf '  gem -v changed: %s -> %s\n' "$PREV_GEMV" "$GEMV"
            printf '  a site_ruby override was installed or removed\n'
            printf '  fix (moves, never deletes):\n'
            # shellcheck disable=SC2016  # $(date) is printed for the user to run
            printf '    TS=$(date +%%Y%%m%%d-%%H%%M%%S); mkdir -p ~/Developer/Backups/site_ruby-stale-$TS\n'
            # shellcheck disable=SC2016  # $TS is set by the line above
            printf '    mv %s/lib/ruby/site_ruby/* ~/Developer/Backups/site_ruby-stale-$TS/\n' \
                "$RGH_HOMEBREW_ROOT"
        fi
    fi

    [ "$drifted" = "0" ] && return 0
    printf '\nRoutine aborted. No step after this one was run.\n'
    exit 3
}

# ---- steps -----------------------------------------------------------------

# A container runtime that actually answers, not merely one installed: OrbStack
# present but stopped produces the same topgrade prompt as none at all.
containers_running() {
    command -v docker >/dev/null 2>&1 || command -v orb >/dev/null 2>&1 || return 1
    docker info >/dev/null 2>&1
}

# A failing step is reported but does not stop the routine. Only ownership or
# version drift counts as evidence of damage; the final health report decides
# the exit code.
run_step() {
    local label="$1"
    shift
    printf '\n==> %s\n    $ %s\n' "$label" "$*"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    (dry run: not executed)\n'
        return 0
    fi
    "$@"
    printf '    exit %d\n' "$?"
}

main() {
    printf '=== %s: topgrade -> mo clean -> brew doctor -> brew cleanup ===\n' "$PROGRAM_NAME"
    [ "$DRY_RUN" = "1" ] && printf '(dry run: measurement only)\n'

    measure
    printf 'baseline:\n'
    show 'before'

    # 1. topgrade. --no-ask-retry removes the interactive
    # "Retry? (y)es/(N)o/(s)hell/(q)uit" prompt. gem and ruby_gems are disabled
    # on purpose: ruby_gems runs `sudo gem update --system`, which is the exact
    # command that caused the 2026-09-16 damage. system is disabled on purpose:
    # a recorded run had the macOS system-update step auto-consent through
    # --yes to downloading a full macOS upgrade and prompt for a password
    # mid-routine; an OS upgrade is a policy decision, not part of maintenance.
    local tg=(topgrade --yes --no-ask-retry
        --disable gem --disable ruby_gems --disable microsoft_office
        --disable system)
    if ! containers_running; then
        printf '\n(no container runtime is answering; Containers step disabled to avoid the retry prompt)\n'
        tg+=(--disable containers)
    fi
    run_step 'topgrade' "${tg[@]}"
    measure
    drift_check topgrade
    show 'after topgrade'
    accept

    # 2. mo clean. Not time-boxed: it prompts, and this wrapper will not answer
    #    for the user. Mole refuses to run as root by itself.
    run_step 'mo clean' mo clean
    measure
    drift_check 'mo clean'
    show 'after mo clean'
    accept

    # 3. brew doctor
    run_step 'brew doctor' env HOMEBREW_NO_AUTO_UPDATE=1 brew doctor
    measure
    drift_check 'brew doctor'
    show 'after brew doctor'
    accept

    # 4. brew cleanup
    run_step 'brew cleanup' brew cleanup
    measure
    drift_check 'brew cleanup'
    show 'after brew cleanup'

    printf '\n==> final Ruby/gem health\n'
    rgh_report
    local health_rc=$?
    if [ "$health_rc" -eq 0 ]; then
        printf '\n=== %s finished; no ownership or version drift at any step ===\n' "$PROGRAM_NAME"
    else
        printf '\n=== %s finished; FAIL lines above - no ownership or version drift during the routine, but health is not clean ===\n' "$PROGRAM_NAME"
    fi
    exit "$health_rc"
}

main "$@"
