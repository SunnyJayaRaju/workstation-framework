# ---------------------------------------------------------------------------
# CANONICAL COPY - templates/guard.zsh
#
# The guard lives under version control here, so it is reviewable and CI can
# exercise it. Nothing installs it for you: install.sh deliberately does not
# touch a user's shell files. To activate it on a machine:
#
#     cp templates/guard.zsh ~/.config/zsh/guard.zsh
#     echo 'source ~/.config/zsh/guard.zsh' >> ~/.zshrc
#
# Interactive shells only. A program that shells out on its own - topgrade
# calling sudo, for example - is not covered; see "WHAT THIS DOES NOT COVER"
# further down for what does cover that case.
#
# Everything below this header is the guard itself, byte for byte, with no
# edits of any kind.
# ---------------------------------------------------------------------------
###############################################################################
# Command Guard — refuse the three commands that caused the 2026-09-16 damage
#
# Added 2026-10-10.
#
# On 2026-09-16 a RubyGems 4.0.21 source tree was written into
# /opt/homebrew/lib/ruby/site_ruby/4.0.0/ with root ownership, because
# `gem update --system` ran with root. Homebrew's Ruby ships 4.0.20. The
# root-owned files then blocked `brew link` and `brew cleanup`.
#
# This guard refuses the three commands that can do that, and only those.
# It changes no other behaviour: `sudo` for anything else, and `gem` for
# anything else, pass straight through to the real command.
#
# BYPASS (deliberate, and it must be typed every time)
#   ALLOW_RISKY_GEM=1 sudo gem install foo
#   ALLOW_RISKY_GEM=1 sudo brew upgrade
#   ALLOW_RISKY_GEM=1 gem update --system
#
#   Prefer `brew install foo` and `brew upgrade`. Homebrew owns Ruby's gems.
#   If you really must run one of these, run it, then immediately run:
#     bash ~/Developer/Tools/scripts/verify-setup.sh
#   and read the "Ruby/gem health" section.
#
# WHAT THIS DOES NOT COVER
#   This guards commands TYPED IN AN INTERACTIVE SHELL. It does not guard a
#   program that shells out on its own. `topgrade` calls
#   `/usr/bin/sudo -E -H .../gem update --system` as a SUBPROCESS: no shell
#   function here is inherited into it, so nothing in this file stops topgrade.
#   Topgrade is protected by two other things, and only by those two:
#     1. ~/.config/topgrade.toml disables the `gem` and `ruby_gems` steps
#     2. mac-routine.sh records root-owned counts and `gem -v` between steps
#        and stops the routine if either changes
#   Anything else that shells out to sudo needs the same treatment.
#
# TO REMOVE THIS GUARD
#   Remove the one `source` line for this file from ~/.zshrc, then delete it.
#   Nothing else depends on it.
#
# Loaded from ~/.zshrc. Runs in every interactive shell.
###############################################################################

# True when an argument is `--system` or any unique abbreviation of it.
#
# Ruby's OptionParser accepts an unambiguous prefix of a long option, so the
# literal string `--system` is NOT the only spelling that reaches
# `opts[:system]`. Measured on 2026-10-10 with the real Gem::OptionParser and
# the real option name from update_command.rb line 39:
#     --sy --sys --syst --syste --system   -> all ACCEPTED, all set system=true
# `--system` is also the only `--s*` long option that command defines, so no
# abbreviation is ambiguous. The earlier version matched only the exact string
# and let `gem update --sys` straight through to the root write.
_rgh_is_system_flag() {
    local a="${1#--}"
    a="${a%%=*}" # --system=4.0.21
    [ -n "$a" ] || return 1
    [[ "system" == "$a"* ]]
}

# True when any argument is `gem` or `brew`, or a PATH to one of them.
#
# Matching ANY argument rather than "the first non-flag argument" is deliberate.
# The obvious version missed `sudo -u me gem install x`, because `me` is the
# value of -u, not the command - a real hole, found by the test that runs
# against it. Parsing sudo's own flags properly would mean reimplementing its
# option table, which changes between sudo versions. Over-refusing is the safe
# direction here: this only affects `sudo`, and the message says exactly how to
# proceed.
#
# The BASENAME is what is matched, via zsh's ${a:t}. Without it,
# `sudo /opt/homebrew/bin/gem update --system` and
# `sudo /opt/homebrew/bin/brew upgrade` both walked straight through, because
# the literal strings are not "gem" or "brew". Measured before the fix: both
# reached the command. `/opt/homebrew/bin` alone has the tail "bin" and is not
# matched, so ordinary work like `sudo ls /opt/homebrew/bin` still passes.
_rgh_names_command() {
    local a
    for a in "$@"; do
        case "${a:t}" in
            gem | brew) return 0 ;;
        esac
    done
    return 1
}

# $1 is the FULL command as typed, including the command word, so the bypass
# line printed below can actually be pasted and run.
_rgh_refuse() {
    local cmd="$1"
    print -u2 -- "refused: ${cmd}"
    print -u2 -- "  This Mac was damaged on 2026-09-16 by a root \`gem update --system\`,"
    print -u2 -- "  which wrote into /opt/homebrew and broke brew link and brew cleanup."
    print -u2 -- "  Use 'brew install <name>' instead. If you are certain, run exactly this:"
    print -u2 -- "    ALLOW_RISKY_GEM=1 ${cmd}"
    print -u2 -- "  then re-run 'bash ~/Developer/Tools/scripts/verify-setup.sh'."
    return 1
}

sudo() {
    if [ "${ALLOW_RISKY_GEM:-0}" != "1" ] && _rgh_names_command "$@"; then
        _rgh_refuse "sudo $*"
        return 1
    fi
    command sudo "$@"
}

gem() {
    if [ "${ALLOW_RISKY_GEM:-0}" != "1" ]; then
        # Any position, not just `gem update --system`: the flag can trail a
        # gem name (`gem install foo --system`), and it can be abbreviated.
        local a
        for a in "$@"; do
            if [ "${a:0:2}" = "--" ] && _rgh_is_system_flag "$a"; then
                _rgh_refuse "gem $*"
                return 1
            fi
        done
    fi
    command gem "$@"
}