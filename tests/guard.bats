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
    for c in sudo gem; do # safety: shim names, not a command
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
# Self-policing. `gem` and `sudo` must resolve to the SHIMS. If either resolves
# anywhere else, this test is about to run the REAL gem or the REAL sudo, and
# on this machine that means a root write into /opt/homebrew: refuse instead.
#
# `whence -p`, not `command -v`. The guard defines gem and sudo as FUNCTIONS,
# and `command -v` on a function prints the word "gem", not a path. `whence -p`
# is zsh's path-only lookup and skips functions, so it reports the executable
# that would actually run.
for _rgh_name in gem sudo; do
    case "$(whence -p $_rgh_name)" in
        "$GUARD_SHIM_DIR"/*) ;;
        *)
            print -u2 -- "REFUSING TO RUN: $_rgh_name resolves to [$(whence -p $_rgh_name)], not a shim"
            exit 99
            ;;
    esac
done
for a in "$@"; do
    eval "gem $a" 2>&1 | sed 's/^/  gem /'
    eval "sudo $a" 2>&1 | sed 's/^/  sudo /'
done
ZSH
    export GUARD_SHIM_DIR="$SHIMDIR"
    export GUARD_PATH="$GUARD"

    # A second runner with no decorative prefix. The guard's own output has to
    # be read character-for-character to check that the bypass line it prints is
    # a runnable command, so nothing may be added to the front of it.
    RAWRUNNER="${BATS_TEST_TMPDIR}/raw.zsh"
    cat >"$RAWRUNNER" <<'ZSH'
export PATH="$GUARD_SHIM_DIR:$PATH"
source "$GUARD_PATH"
# Same self-policing as the other runner, and for the same `whence -p` reason.
for _rgh_name in gem sudo; do
    case "$(whence -p $_rgh_name)" in
        "$GUARD_SHIM_DIR"/*) ;;
        *)
            print -u2 -- "REFUSING TO RUN: $_rgh_name resolves to [$(whence -p $_rgh_name)], not a shim"
            exit 99
            ;;
    esac
done
eval "$GUARD_CMD"
ZSH
}

# Runs one command line against the guard with NO prefix added to its output.
#
# The command line is evaluated inside zsh, never in bats' own shell. This is
# not a style rule. An earlier version of the bypass test ran
#   eval "$bypass"
# in bats' bash, where `gem` and `sudo` are the REAL binaries. The bypass line
# it evaluated was "ALLOW_RISKY_GEM=1 gem update --sys", which sets the guard's
# own bypass variable and then runs a real system-wide RubyGems update. That
# installed 591 files into /opt/homebrew/lib/ruby/site_ruby on 2026-10-10.
run_guard_raw() {
    GUARD_CMD="$1" run /bin/zsh "$RAWRUNNER"
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

@test "guard refuses sudo by BASENAME, not by literal string" {
    # `sudo /opt/homebrew/bin/gem update --system` and the brew equivalent both
    # walked straight through before: the argument is not the string "gem", it is
    # a path ending in it. Matched with zsh ${a:t}, the tail.
    sudo_refused "/opt/homebrew/bin/gem update --system"
    sudo_refused "/opt/homebrew/bin/brew upgrade"
    sudo_refused "/usr/local/bin/gem install foo"
}

@test "guard still passes sudo through for a path that merely ends in bin" {
    run_guard "ls /opt/homebrew/bin"
    [[ "$output" == *"REACHED-REAL-sudo: ls /opt/homebrew/bin"* ]]
    [[ "$output" != *"refused:"* ]]
}

# ---------------------------------------------------------------------------
# The printed bypass must be runnable as-is. It used to be built from the
# arguments alone, so a refusal of `sudo gem install foo` printed
#   ALLOW_RISKY_GEM=1 gem install foo
# which drops the sudo and is NOT the command that was blocked.
# ---------------------------------------------------------------------------

@test "the bypass line names the command word that was refused" {
    run_guard_raw "sudo gem install foo"
    [[ "$output" == *"ALLOW_RISKY_GEM=1 sudo gem install foo"* ]]

    run_guard_raw "gem update --system"
    [[ "$output" == *"ALLOW_RISKY_GEM=1 gem update --system"* ]]
}

@test "the refusal headline also names the command word" {
    # Raw runner: the decorated one prefixes every line with "  gem " or
    # "  sudo ", which would hide the exact text being asserted on.
    run_guard_raw "sudo gem install foo"
    [[ "$output" == *"refused: sudo gem install foo"* ]]

    run_guard_raw "gem update --sys"
    [[ "$output" == *"refused: gem update --sys"* ]]
}

@test "the runners refuse to run unless gem and sudo resolve to the shims" {
    # The self-policing guard inside each runner, proved to actually fire by
    # pointing GUARD_SHIM_DIR somewhere that is not on PATH at all. Without
    # this, the safety check is code that has never been seen to fail.
    run env GUARD_SHIM_DIR="${BATS_TEST_TMPDIR}/nowhere" \
        GUARD_PATH="$GUARD" GUARD_CMD="gem list" \
        /bin/zsh "$RAWRUNNER"
    [ "$status" -eq 99 ]
    [[ "$output" == *"REFUSING TO RUN"* ]]
    [[ "$output" == *"not a shim"* ]]
    [[ "$output" != *"REACHED-REAL"* ]]
    # It must name the binary it would otherwise have run. That path is NOT
    # hardcoded: it is whatever gem resolves to in this run, which is the
    # suite-wide fake now that test_helper fences the PATH. Hardcoding the real
    # /opt/homebrew/bin/gem is what this test used to assert, and the fence
    # correctly made that assertion fail.
    local resolved
    resolved="$(command -v gem)"
    [[ "$output" == *"$resolved"* ]]
    [[ "$resolved" != "${BATS_TEST_TMPDIR}/nowhere"* ]]
}

@test "the shims really are what the runners resolve" {
    # The positive half of the same guarantee: with GUARD_SHIM_DIR set
    # correctly, gem and sudo resolve to the shim, not to /opt/homebrew/bin or
    # /usr/bin. This is what makes "REFUSING TO RUN" mean something.
    run env GUARD_SHIM_DIR="$SHIMDIR" GUARD_PATH="$GUARD" GUARD_CMD="gem list" \
        /bin/zsh "$RAWRUNNER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"REACHED-REAL-gem: list"* ]]
}

@test "the printed bypass, run verbatim, reaches the command" {
    # Extract the line the guard printed and actually execute it. That is the
    # only way to know the text is a runnable command and not a slogan.
    run_guard_raw "gem update --sys"
    local bypass
    bypass="$(printf '%s\n' "$output" |
        sed -n 's/^[[:space:]]*\(ALLOW_RISKY_GEM=1 .*\)$/\1/p')"
    [ -n "$bypass" ]
    [[ "$bypass" == ALLOW_RISKY_GEM=1* ]]
    [[ "$bypass" == *"gem"* ]]
    # Executed by zsh, never by bats' bash. In bash, `gem` and `sudo` are the
    # REAL binaries and this would run the very command the guard refused.
    local out
    out="$(GUARD_CMD="$bypass" /bin/zsh "$RAWRUNNER" 2>&1)"
    [[ "$out" == *"REACHED-REAL-gem: update --sys"* ]]
}

@test "the printed sudo bypass, run verbatim, reaches the command" {
    run_guard_raw "sudo gem install foo"
    local bypass
    bypass="$(printf '%s\n' "$output" |
        sed -n 's/^[[:space:]]*\(ALLOW_RISKY_GEM=1 .*\)$/\1/p')"
    [ -n "$bypass" ]
    [[ "$bypass" == ALLOW_RISKY_GEM=1* ]]
    [[ "$bypass" == *"sudo"* ]]
    # Executed by zsh, never by bats' bash, so `sudo` is the shim and not sudo.
    local out
    out="$(GUARD_CMD="$bypass" /bin/zsh "$RAWRUNNER" 2>&1)"
    [[ "$out" == *"REACHED-REAL-sudo: gem install foo"* ]]
}

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

# REPLACED, deliberately: the previous version of this test executed the real
# topgrade binary with `--run-type dry`.
#
# `--run-type dry` is documented to print commands instead of running them, and
# it was measured to leave /opt/homebrew untouched. It was still the wrong
# thing for a test to do. On 2026-10-10 this very suite installed 591 files into
# /opt/homebrew by evaluating a command string in the wrong shell, and the
# lesson was not "be careful which flags you pass to a real binary", it was
# "a test must not start a real binary that can reach the machine". topgrade is
# a program whose entire purpose is running gem, brew and sudo. Even in dry
# mode, whether it is safe is a property of topgrade's current build, not of
# this repository, and it changes on every upgrade.
#
# The claim itself does not need topgrade to be true, so it is asserted from a
# capture instead. The fixture records a real run of
# `topgrade --config <empty> --run-type dry` and is provenance-documented in the
# file. Nothing is executed and nothing can drift into executing.
@test "the captured topgrade dry run shows it would call sudo gem update --system" {
    local fixture="${PROJECT_ROOT}/tests/fixtures/topgrade-dry-ruby_gems.txt"
    [ -r "$fixture" ] || {
        echo "missing fixture: $fixture" >&2
        return 1
    }
    local content
    content="$(cat "$fixture")"
    # The claim the config guard exists for: with nothing disabled, topgrade
    # reaches for sudo to update RubyGems system-wide.
    [[ "$content" == *"sudo"* ]]
    [[ "$content" == *"gem update --system"* ]]
    [[ "$content" == *"Dry running:"* ]]
}

@test "the fixture records the dry run, not an execution" {
    local fixture="${PROJECT_ROOT}/tests/fixtures/topgrade-dry-ruby_gems.txt"
    # Every command line in the capture is prefixed "Dry running:". If a real
    # execution were ever pasted in, that prefix would be gone.
    local commands
    commands="$(grep -c '^Dry running: ' "$fixture")"
    [ "$commands" -ge 2 ]
    ! grep -qE '^Done|^Updated|^Installing' "$fixture"
}

@test "the real topgrade config disables both gem steps" {
    local cfg="$HOME/.config/topgrade.toml"
    [ -r "$cfg" ] || skip "no topgrade config at $cfg"
    grep -qE '^[[:space:]]*disable[[:space:]]*=.*"gem"' "$cfg"
    grep -qE '^[[:space:]]*disable[[:space:]]*=.*ruby_gems' "$cfg"
}