#!/usr/bin/env bash

###############################################################################
# Library: ruby_gem_health.sh
# Version: see VERSION file
#
# Purpose:
#   Detect the exact damage a root `gem update --system` leaves behind on a
#   Homebrew Ruby, so it cannot silently return.
#
#   2026-09-16: a RubyGems 4.0.21 source tree was written into
#   /opt/homebrew/lib/ruby/site_ruby/4.0.0/ with root ownership (Homebrew's
#   Ruby ships 4.0.20). The root-owned files then blocked `brew link` and
#   `brew cleanup`. Nothing in the old harness could see any of it.
#
# CONTRACT
#   Every function here is READ-ONLY and NEVER calls sudo. Each check function
#   prints exactly one verdict line to stdout:
#
#       "PASS  <detail>"
#       "WARN  <detail>"
#       "FAIL  <detail>"
#
#   followed by zero or more indented "      <detail>" continuation lines.
#   The caller owns the vocabulary (verify-setup.sh maps FAIL to its own fail(),
#   tests assert on the same string), so there is exactly one implementation.
#
# ROOTS ARE OVERRIDABLE
#   RGH_HOMEBREW_ROOT (default /opt/homebrew)
#   RGH_GEM_HOME      (default $HOME/.gem)
#   Tests point both at a temp fixture. Nothing here ever writes.
###############################################################################

RGH_HOMEBREW_ROOT="${RGH_HOMEBREW_ROOT:-/opt/homebrew}"
RGH_GEM_HOME="${RGH_GEM_HOME:-$HOME/.gem}"
# Which owner counts as the wrong one. `root` on every real run. A test may
# point it at the test's own uid to prove the ownership check FAILs, since no
# test can create a root-owned file without sudo; the production path is
# unchanged. Never set this outside a test.
RGH_ROOT_USER="${RGH_ROOT_USER:-root}"

# Print one verdict line. Kept as a function so no call site builds the
# prefix by hand and drifts.
rgh_say() { printf '%s\n' "$1"; }

# Print a continuation line under the previous verdict.
rgh_detail() { printf '      %s\n' "$1"; }

# --------------------------------------------------------------------- facts

# Count of entries under <dir> owned by root. A directory that does not exist
# is 0, not an error: a Mac with no Homebrew has nothing to find, and reporting
# that as a fault would be a false alarm on a healthy machine.
rgh_root_owned_count() {
    local dir="$1" n
    [ -d "$dir" ] || {
        printf '0'
        return 0
    }
    n=$(find "$dir" -user "$RGH_ROOT_USER" 2>/dev/null | wc -l | tr -d ' ')
    printf '%s' "${n:-0}"
}

# Newline-separated paths of every root-owned entry under the given roots.
# Used by mac-routine.sh to name what appeared, not just how many.
rgh_root_owned_list() {
    local d
    for d in "$@"; do
        [ -d "$d" ] || continue
        find "$d" -user "$RGH_ROOT_USER" 2>/dev/null
    done
}

# Newline-separated paths of files under <dir>/site_ruby/<any>/*.
# An EMPTY site_ruby directory is healthy - that is the state after the
# override has been moved aside. Only actual files are reported.
rgh_site_ruby_files() {
    local root="$1"
    [ -d "$root" ] || return 0
    find "$root/lib/ruby/site_ruby" -type f 2>/dev/null
}

# The RubyGems version the active ruby actually loads, read out of the
# rubygems.rb it required. Read from the LOADED file rather than from a guessed
# path: /opt/homebrew/lib/ruby is not a symlink on this machine, so a hardcoded
# path would be a guess, and the loaded file is the authority either way.
rgh_shipped_gem_version() {
    local ruby_bin="${1:-ruby}" path
    command -v "$ruby_bin" >/dev/null 2>&1 || return 0
    # shellcheck disable=SC2016  # Ruby, not bash: $LOADED_FEATURES is Ruby's
    path=$("$ruby_bin" -e 'require "rubygems"; print $LOADED_FEATURES.grep(/rubygems\.rb$/).first' 2>/dev/null) || return 0
    [ -n "$path" ] && [ -r "$path" ] || return 0
    grep -m1 -E '^[[:space:]]*VERSION[[:space:]]*=' "$path" 2>/dev/null |
        sed -E 's/.*"([^"]+)".*/\1/'
}

# `gem -v` on PATH. Empty when gem is absent or broken.
rgh_active_gem_version() {
    command -v gem >/dev/null 2>&1 || return 0
    gem -v 2>/dev/null | tr -d '[:space:]'
}

# Plugin .rb files under any ~/.gem/ruby/*/plugins/ whose absolute target is
# missing. A plugin shim left behind by an old Ruby points at a keg path that
# no longer exists, and Ruby then fails at load time rather than skipping it.
#
# Resolution is done here rather than by shelling out to Ruby: the target is a
# literal path inside a require_relative line, so it can be read directly.
rgh_dangling_plugins() {
    local f target
    [ -d "$RGH_GEM_HOME/ruby" ] || return 0
    for f in "$RGH_GEM_HOME"/ruby/*/plugins/*.rb; do
        [ -f "$f" ] || continue
        target=$(grep -m1 -oE "require_relative '[^']+'" "$f" 2>/dev/null |
            sed -E "s/^require_relative '//; s/'\$//") || true
        [ -n "$target" ] || continue
        # require_relative resolves against the file's own directory.
        target="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/${target}"
        [ -e "$target" ] || printf '%s\n' "$f"
    done
}

# Commands under any ~/.gem/ruby/*/bin/ whose #! interpreter is missing.
# These are the 14 rubocop/bundle/rake wrappers: they keep a hardcoded
# /opt/homebrew/opt/ruby shebang, so a Ruby keg change breaks them silently -
# the file stays, the command stops working.
rgh_dangling_shebang_commands() {
    local f interp
    [ -d "$RGH_GEM_HOME/ruby" ] || return 0
    for f in "$RGH_GEM_HOME"/ruby/*/bin/*; do
        [ -f "$f" ] || continue
        interp=$(head -n1 "$f" 2>/dev/null)
        case "$interp" in
            '#!'*) ;;
            *) continue ;;
        esac
        interp="${interp#\#!}"
        # Strip a trailing interpreter argument (e.g. `#!/usr/bin/env ruby`).
        interp="${interp%% *}"
        # `env ruby` resolves through PATH; only absolute paths are checkable
        # without running anything.
        case "$interp" in
            /*) [ -x "$interp" ] || printf '%s -> %s\n' "$f" "$interp" ;;
        esac
    done
}

# Distinct interpreters targeted by ~/.gem/ruby/*/bin, one per line. Informational:
# a Ruby upgrade moves the keg this points at, so it should never be a surprise.
rgh_shebang_targets() {
    # seen is pipe-delimited with a LEADING pipe. Without it the membership
    # pattern `*"|$interp|"*` never matches the first entry, because there is no
    # separator in front of it - which silently duplicated every target. Caught
    # by running this against the real 14 commands, which all share one
    # shebang and printed it twice.
    local f interp seen="|"
    [ -d "$RGH_GEM_HOME/ruby" ] || return 0
    for f in "$RGH_GEM_HOME"/ruby/*/bin/*; do
        [ -f "$f" ] || continue
        interp=$(head -n1 "$f" 2>/dev/null)
        case "$interp" in '#!'*) ;; *) continue ;; esac
        interp="${interp#\#!}"
        interp="${interp%% *}"
        case "$seen" in
            *"|$interp|"*) ;;
            *) seen="${seen}${interp}|" ;;
        esac
    done
    printf '%s\n' "${seen#|}" | tr '|' '\n'
}

# Gem names with more than one version directory inside ~/.gem ONLY.
#
# Deliberately does not read `gem list`. That output mixes the user tree with
# Homebrew's default gems and marks them "default: 1.2.3"; treating those as
# duplicates produces a permanent false warning on a healthy machine. Bundled
# and default gems live in the Cellar, cannot be removed by the user, and are
# expected. Only the user's own tree is inspected.
rgh_duplicate_gems() {
    local dir
    [ -d "$RGH_GEM_HOME/ruby" ] || return 0
    for dir in "$RGH_GEM_HOME"/ruby/*/gems; do
        [ -d "$dir" ] || continue
        # A gem directory name is `<name>-<version>` with no whitespace, so `ls` is
        # safe here and reads more clearly than a find+basename pipeline would.
        # shellcheck disable=SC2012
        ls -1 "$dir" 2>/dev/null |
            sed -E 's/-[0-9][^-]*$//' |
            sort |
            uniq -d
    done | sort -u
}

# `brew doctor` lines that mean an unlinked or old keg is stuck. Returns the
# count on stdout; the verdict text is the caller's business.
#
# Matching is on phrases brew doctor actually emits. A machine with no brew, or
# brew that is merely noisy about something else, reports 0 rather than a fault.
rgh_brew_keg_problem_count() {
    local out n
    command -v brew >/dev/null 2>&1 || {
        printf '0'
        return 0
    }
    # HOMEBREW_NO_AUTO_UPDATE=1 is load-bearing, not hygiene. `brew doctor`
    # runs an implicit `brew update` without it, and that fetches and rewrites
    # the taps. Measured on 2026-10-10: 52 entries under /opt/homebrew carried
    # that day's mtime purely from health checks. A diagnostic must not change
    # the machine it measures. Same flag mac-maintain already uses.
    #
    # Measured limit of the flag, stated so nobody over-reads it: with the flag
    # set, `brew doctor` still bumps the mtime of two DIRECTORIES, /opt/homebrew/.git
    # and homebrew-core/.git, because git opens them. No file content changes and
    # nothing is fetched. Two directory mtimes is not a tap update.
    out="$(HOMEBREW_NO_AUTO_UPDATE=1 brew doctor 2>&1)" || true
    n=$(printf '%s' "$out" |
        grep -icE 'unlinked|broken (link|symlink)|keg.*(not|un)(linked|readable)|Permission denied' || true)
    printf '%s' "${n:-0}"
}

rgh_brew_doctor_problem_lines() {
    command -v brew >/dev/null 2>&1 || return 0
    HOMEBREW_NO_AUTO_UPDATE=1 brew doctor 2>&1 |
        grep -iE 'unlinked|broken (link|symlink)|keg.*(not|un)(linked|readable)|Permission denied' |
        head -3 || true
}

# ------------------------------------------------------------------- checks

# 1. Nothing under Homebrew or the user gem tree is owned by root.
#    FAIL. The fix needs root and is printed, never run.
rgh_check_root_ownership() {
    local hb gem_n
    hb=$(rgh_root_owned_count "$RGH_HOMEBREW_ROOT")
    gem_n=$(rgh_root_owned_count "$RGH_GEM_HOME")

    if [ "$hb" = "0" ] && [ "$gem_n" = "0" ]; then
        rgh_say "PASS  no root-owned files under ${RGH_HOMEBREW_ROOT} or ${RGH_GEM_HOME}"
        return 0
    fi
    rgh_say "FAIL  root-owned entries: ${RGH_HOMEBREW_ROOT} ${hb}, ${RGH_GEM_HOME} ${gem_n}"
    rgh_detail "these came from a root \`gem update --system\` against Homebrew Ruby"
    rgh_detail "fix (needs your password, run it yourself):"
    rgh_detail "  sudo find ${RGH_HOMEBREW_ROOT} -user root -exec chown -h \"\$(whoami)\":admin {} +"
    return 1
}

# 2a. `gem -v` must equal the RubyGems version the active Homebrew Ruby ships.
#     A mismatch means a site_ruby override shadowed the shipped one.
rgh_check_gem_version_parity() {
    local active shipped
    active=$(rgh_active_gem_version)
    shipped=$(rgh_shipped_gem_version)

    if [ -z "$active" ] || [ -z "$shipped" ]; then
        rgh_say "FAIL  could not read both gem versions (gem='${active:-none}' rubygems.rb='${shipped:-none}') - the parity check measured nothing"
        rgh_detail "fix:  brew install ruby   (then re-run)"
        return 1
    fi
    if [ "$active" = "$shipped" ]; then
        rgh_say "PASS  gem ${active} matches the RubyGems shipped inside the active Homebrew Ruby"
        return 0
    fi
    rgh_say "FAIL  gem reports ${active} but the Homebrew Ruby ships ${shipped} - a site_ruby override is loaded"
    rgh_detail "fix (moves, never deletes):"
    rgh_detail "  TS=\$(date +%Y%m%d-%H%M%S)"
    rgh_detail "  mkdir -p ~/Developer/Backups/site_ruby-stale-\$TS"
    rgh_detail "  mv ${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/* ~/Developer/Backups/site_ruby-stale-\$TS/"
    rgh_detail "  undo: mv ~/Developer/Backups/site_ruby-stale-\$TS/* ${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/"
    return 1
}

# 2b. site_ruby must hold no files. An empty directory is the healthy state.
rgh_check_site_ruby_empty() {
    local f n=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        n=$((n + 1))
        [ "$n" -le 3 ] && rgh_detail "override file: ${f}"
    done < <(rgh_site_ruby_files "$RGH_HOMEBREW_ROOT")

    if [ "$n" = "0" ]; then
        rgh_say "PASS  ${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby holds no override files"
        return 0
    fi
    rgh_say "FAIL  site_ruby contains file(s) - a root \`gem update --system\` wrote its source tree here"
    [ "$n" -gt 3 ] && rgh_detail "($n files total)"
    rgh_detail "fix (moves, never deletes):"
    rgh_detail "  TS=\$(date +%Y%m%d-%H%M%S)"
    rgh_detail "  mkdir -p ~/Developer/Backups/site_ruby-stale-\$TS"
    rgh_detail "  mv ${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/* ~/Developer/Backups/site_ruby-stale-\$TS/"
    return 1
}

# 3. brew doctor must not report an unlinked or unreadable keg.
rgh_check_brew_kegs() {
    local n
    n=$(rgh_brew_keg_problem_count)
    if [ "$n" = "0" ]; then
        rgh_say "PASS  brew doctor reports no unlinked or unreadable keg"
        return 0
    fi
    rgh_say "FAIL  brew doctor reports ${n} keg problem(s) that block link and cleanup"
    rgh_brew_doctor_problem_lines | while IFS= read -r l; do rgh_detail "$l"; done
    rgh_detail "fix: brew link --overwrite <formula>   (or brew reinstall <formula>)"
    return 1
}

# 4. No plugin may point at a path that no longer exists, and no command may
#    have a shebang to a missing interpreter.
rgh_check_gem_wiring() {
    local p n=0
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        n=$((n + 1))
        rgh_detail "stale plugin: ${p}"
    done < <(rgh_dangling_plugins)

    local c
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        n=$((n + 1))
        rgh_detail "broken command: ${c}"
    done < <(rgh_dangling_shebang_commands)

    if [ "$n" = "0" ]; then
        rgh_say "PASS  every ~/.gem plugin resolves and every ~/.gem command has a live interpreter"
        return 0
    fi
    rgh_say "FAIL  ${n} broken ~/.gem reference(s) - see the paths above"
    rgh_detail "fix (moves, never deletes):"
    rgh_detail "  TS=\$(date +%Y%m%d-%H%M%S)"
    rgh_detail "  mkdir -p ~/Developer/Backups/gem-stale-\$TS"
    rgh_detail "  mv <the listed files> ~/Developer/Backups/gem-stale-\$TS/"
    rgh_detail "  undo: mv ~/Developer/Backups/gem-stale-\$TS/* <their original paths>"
    return 1
}

# 5. Duplicate gem versions inside ~/.gem only. WARN, never FAIL: an extra copy
#    is untidy and can shadow, but it is not the root-ownership damage.
rgh_check_duplicate_gems() {
    local d n=0
    while IFS= read -r d; do
        [ -n "$d" ] || continue
        n=$((n + 1))
        rgh_detail "duplicate in ~/.gem: ${d}"
    done < <(rgh_duplicate_gems)

    if [ "$n" = "0" ]; then
        rgh_say "PASS  no duplicate gem versions inside ~/.gem (Homebrew's bundled/default gems excluded by design)"
        return 0
    fi
    rgh_say "WARN  ${n} gem(s) have more than one version inside ~/.gem"
    rgh_detail "fix: gem cleanup --user-install    (plain \`gem cleanup\` only touches the Cellar, which is always empty)"
    return 0
}

# 6. INFO only: what the ~/.gem commands point at, so a Ruby keg change is not
#    a surprise. Never FAIL - an old-looking target that still resolves is fine.
rgh_check_shebang_targets() {
    local t
    t=$(rgh_shebang_targets)
    if [ -z "$t" ]; then
        rgh_say "INFO  no ~/.gem/ruby/*/bin commands to report"
        return 0
    fi
    rgh_say "INFO  ~/.gem/ruby/*/bin shebang target(s):"
    printf '%s\n' "$t" | while IFS= read -r l; do [ -n "$l" ] && rgh_detail "$l"; done
    rgh_detail "these follow the Homebrew ruby keg via /opt/homebrew/opt/ruby;"
    rgh_detail "a \`brew upgrade ruby\` repoints that symlink, so they keep working."
    return 0
}

# Run every check, in order, each printing one verdict line.
rgh_report() {
    rgh_check_root_ownership
    rgh_check_gem_version_parity
    rgh_check_site_ruby_empty
    rgh_check_brew_kegs
    rgh_check_gem_wiring
    rgh_check_duplicate_gems
    rgh_check_shebang_targets
}
