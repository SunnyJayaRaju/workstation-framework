#!/usr/bin/env bats

load test_helper

# ---------------------------------------------------------------------------
# guard.zsh lives at ~/.config/zsh/guard.zsh, outside this repository, so it
# has to be exercised the way it actually runs: sourced into a real zsh, with
# `gem` and `sudo` shimmed as executables on PATH so the guard's own functions
# stay in place and its pass-through path runs for real.
#
# Nothing here can reach sudo or the real gem. The shims only print.
#
# The runner script is written with a QUOTED heredoc and takes the two paths it
# needs from the environment. An unquoted heredoc was the first attempt: `$a`
# and `$@` expanded while the file was being written, so every command reached
# the guard with no arguments and the tests passed or failed for the wrong
# reason. Paths come in as variables, so there is nothing to escape.
#
# SKIP when the guard is absent, so a clone without this machine's shell setup
# is not a failure. The guard is a machine-level control, not a packaged
# feature.
# ---------------------------------------------------------------------------

setup() {
    GUARD="${GUARD_ZSH:-$HOME/.config/zsh/guard.zsh}"
    if [ ! -r "$GUARD" ]; then
        skip "guard.zsh not present at $GUARD"
    fi

    SHIMDIR="${BATS_TEST_TMPDIR}/shim"
    mkdir -p "$SHIMDIR"
    for c in sudo gem; do
        cat >"${SHIMDIR}/$c" <<'SH'
#!/bin/sh
echo "REACHED-REAL-$(basename "$0"): $*"
exit 0
SH
        chmod +x "${SHIMDIR}/$c"
    done

    RUNNER="${BATS_TEST_TMPDIR}/run.zsh"
    cat >"$RUNNER" <<'ZSH'
export PATH="$GUARD_SHIM_DIR:$PATH"
source "$GUARD_PATH"
for a in "$@"; do
    eval "gem $a" 2>&1 | sed 's/^/  gem /'
    eval "sudo $a" 2>&1 | sed 's/^/  sudo /'
done
ZSH
    export GUARD_SHIM_DIR="$SHIMDIR"
    export GUARD_PATH="$GUARD"
}

# Runs `gem <args>` and `sudo <args>` against the shims.
run_guard() {
    run /bin/zsh "$RUNNER" "$@"
}

# True when `gem <args>` was refused.
gem_refused() {
    run_guard "$@"
    [[ "$output" == *"gem refused:"* ]]
}

# True when `sudo <args>` was refused.
sudo_refused() {
    run_guard "$@"
    [[ "$output" == *"sudo refused:"* ]]
}

# ---------------------------------------------------------------------------
# The original three: these were the whole brief.
# ---------------------------------------------------------------------------

@test "guard refuses sudo gem install foo" {
    sudo_refused "gem install foo"
}

@test "guard refuses sudo brew upgrade" {
    sudo_refused "brew upgrade"
}

@test "guard refuses gem update --system" {
    gem_refused "update --system"
}

# ---------------------------------------------------------------------------
# Abbreviations. RubyGems parses options with Gem::OptionParser, which accepts
# any unambiguous prefix of a long option, so `--sys` reaches opts[:system].
# Measured on 2026-10-10 against the real parser and the real option name from
# update_command.rb line 39: --sy --sys --syst --syste --system all accepted.
# ---------------------------------------------------------------------------

@test "guard refuses every abbreviation of --system, two characters and up" {
    local flag
    for flag in --sy --sys --syst --syste --system; do
        gem_refused "update ${flag}" || {
            echo "NOT REFUSED: gem update ${flag}" >&2
            echo "$output" >&2
            return 1
        }
    done
}

@test "guard refuses an abbreviation carrying a value" {
    gem_refused "update --sys=4.0.21"
}

@test "guard refuses an abbreviation that trails a gem name" {
    gem_refused "install foo --syste"
}

# ---------------------------------------------------------------------------
# Everything else must still reach the real command untouched.
# ---------------------------------------------------------------------------

@test "guard passes sudo through for everything except gem and brew" {
    run_guard "docker ps" "apt-get install x" "ls -l"
    [[ "$output" == *"REACHED-REAL-sudo: docker ps"* ]]
    [[ "$output" == *"REACHED-REAL-sudo: apt-get install x"* ]]
    [[ "$output" == *"REACHED-REAL-sudo: ls -l"* ]]
    [[ "$output" != *"refused:"* ]]
}

@test "guard passes gem through for every non-system update" {
    run_guard "list" "install colorize" "cleanup" "update --user-install" "update"
    [[ "$output" == *"REACHED-REAL-gem: list"* ]]
    [[ "$output" == *"REACHED-REAL-gem: install colorize"* ]]
    [[ "$output" == *"REACHED-REAL-gem: cleanup"* ]]
    [[ "$output" == *"REACHED-REAL-gem: update --user-install"* ]]
    [[ "$output" == *"REACHED-REAL-gem: update"* ]]
    [[ "$output" != *"refused:"* ]]
}

@test "a --s option that is not a prefix of --system is not over-refused" {
    # The guard matches prefixes of the word "system", not every --s flag.
    run_guard "install --no-document" "uninstall --executables"
    [[ "$output" == *"REACHED-REAL-gem: install --no-document"* ]]
    [[ "$output" == *"REACHED-REAL-gem: uninstall --executables"* ]]
    [[ "$output" != *"refused:"* ]]
}

# ---------------------------------------------------------------------------
# The bypass, and the documented limit of what this file protects.
# ---------------------------------------------------------------------------

@test "ALLOW_RISKY_GEM=1 lets an abbreviated system update through" {
    local out
    out="$(ALLOW_RISKY_GEM=1 /bin/zsh "$RUNNER" "update --sys" 2>&1)"
    [[ "$out" == *"REACHED-REAL-gem: update --sys"* ]]
    [[ "$out" != *"refused:"* ]]
}

@test "ALLOW_RISKY_GEM=1 lets sudo gem through" {
    local out
    out="$(ALLOW_RISKY_GEM=1 /bin/zsh "$RUNNER" "gem install foo" 2>&1)"
    [[ "$out" == *"REACHED-REAL-sudo: gem install foo"* ]]
    [[ "$out" != *"refused:"* ]]
}

@test "the guard documents that it does not cover topgrade" {
    grep -q 'SUBPROCESS' "$GUARD"
    grep -q 'topgrade.toml disables' "$GUARD"
}

@test "the README states the same limit" {
    run grep -qi 'interactive shell' "${PROJECT_ROOT}/README.md"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# The real topgrade, to keep the documented claim honest rather than assumed.
# ---------------------------------------------------------------------------

to() {
    perl -e 'alarm shift; exec @ARGV' "$@"
}

@test "topgrade really does call sudo gem update --system" {
    command -v topgrade >/dev/null 2>&1 || skip "topgrade not installed"
    local cfg="${BATS_TEST_TMPDIR}/empty.toml"
    printf '[misc]\n' >"$cfg"
    # --run-type dry executes no step, so nothing is written and sudo is unused.
    local out
    out="$(to 120 topgrade --config "$cfg" --run-type dry 2>&1 || true)"
    [[ "$out" == *"gem update --system"* ]]
}

@test "the real topgrade config disables both gem steps" {
    local cfg="$HOME/.config/topgrade.toml"
    [ -r "$cfg" ] || skip "no topgrade config at $cfg"
    grep -qE '^[[:space:]]*disable[[:space:]]*=.*"gem"' "$cfg"
    grep -qE '^[[:space:]]*disable[[:space:]]*=.*ruby_gems' "$cfg"
}