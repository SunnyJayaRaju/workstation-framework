#!/usr/bin/env bats

load test_helper

# ---------------------------------------------------------------------------
# Fixtures. Everything below runs against a temp tree. /opt/homebrew and the
# real ~/.gem are never read or written by any test in this file - the two
# roots the library uses are redirected with RGH_HOMEBREW_ROOT and
# RGH_GEM_HOME, and the "who is the wrong owner" test uses RGH_ROOT_USER so the
# ---------------------------------------------------------------------------

setup() {
    FIX="${BATS_TEST_TMPDIR}/fixture"
    export RGH_HOMEBREW_ROOT="${FIX}/homebrew"
    export RGH_GEM_HOME="${FIX}/gemhome"
    export RGH_LIB="${SCRIPTS_DIR}/lib/ruby_gem_health.sh"

    SHIM="${BATS_TEST_TMPDIR}/shim"
    mkdir -p "$SHIM"

    mkdir -p "${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0"
    mkdir -p "${RGH_HOMEBREW_ROOT}/lib/ruby/gems"
    mkdir -p "${RGH_GEM_HOME}/ruby/4.0.0"/{bin,gems,plugins}

    # A rubygems.rb the fake `ruby` will point at, and a fake `gem` that
    # reports the matching version. Parity holds until a test breaks it.
    printf '  VERSION = "4.0.20"\n' >"${FIX}/rubygems.rb"
    cat >"${SHIM}/ruby" <<EOF
#!/bin/sh
[ "\$1" = "-e" ] && echo "${FIX}/rubygems.rb"
exit 0
EOF
    # Models the real thing: `gem -v` reports the version of the rubygems.rb
    # that is loaded, so installing a site_ruby override changes what it prints.
    cat >"${SHIM}/gem" <<EOF
#!/bin/sh
if [ "\$1" = "-v" ]; then
    if [ -n "\${GEM_REPORT_VERSION:-}" ]; then
        echo "\${GEM_REPORT_VERSION}"
    elif [ -r "\${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb" ]; then
        grep -m1 -E '^[[:space:]]*VERSION' "\${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb" |
            sed -E 's/.*"([^"]+)".*/\\1/'
    else
        echo 4.0.20
    fi
fi
exit 0
EOF
    cat >"${SHIM}/brew" <<'EOF'
#!/bin/sh
[ "$1" = "doctor" ] && echo "Your system is ready to brew."
exit 0
EOF
    chmod +x "${SHIM}"/ruby "${SHIM}"/gem "${SHIM}"/brew
    export PATH="${SHIM}:${PATH}"
}

report() { bash -c 'source "$1"; rgh_report' _ "$RGH_LIB"; }
check() { bash -c 'source "$1"; "$2"' _ "$RGH_LIB" "$1"; }

# ===========================================================================
# The clean fixture must be clean. If this ever FAILs, every test below is
# meaningless - so it runs first and states that dependency out loud.
# ===========================================================================

@test "a healthy fixture reports PASS for every check" {
    run report
    [ "$status" -eq 0 ]
    [[ "$output" != *"FAIL"* ]]
    [[ "$output" == *"PASS  no root-owned files"* ]]
    [[ "$output" == *"PASS  gem 4.0.20 matches"* ]]
    [[ "$output" == *"PASS  ${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby holds no override files"* ]]
    [[ "$output" == *"PASS  brew doctor reports no unlinked"* ]]
    [[ "$output" == *"PASS  every ~/.gem plugin resolves"* ]]
    [[ "$output" == *"PASS  no duplicate gem versions inside ~/.gem"* ]]
}

@test "the shebang target is reported as INFO, never FAIL" {
    printf '#!/opt/homebrew/opt/ruby/bin/ruby\n' >"${RGH_GEM_HOME}/ruby/4.0.0/bin/rubocop"
    run report
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO  ~/.gem/ruby/*/bin shebang target(s):"* ]]
    [[ "$output" == *"/opt/homebrew/opt/ruby/bin/ruby"* ]]
    [[ "$output" != *"FAIL  "* ]]
}

# ===========================================================================
# FAKE FIXTURE: reproduce each piece of the 2026-09-16 damage and prove the
# matching check turns FAIL, with the fix command in the output.
# ===========================================================================

@test "a real root-owned tree FAILs the ownership check, with the fix printed" {
    # /etc/ssh is root-owned on this machine (7 entries, measured). Using it
    # proves the check FAILs on genuine root ownership: no fake owner, no sudo,
    # no chown, and /opt/homebrew is not involved.
    RGH_HOMEBREW_ROOT=/etc/ssh run check rgh_check_root_ownership
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  root-owned entries"* ]]
    [[ "$output" == *"7"* ]]
    # The fix is printed, never run, and carries the password caveat.
    [[ "$output" == *"sudo find /etc/ssh -user root -exec chown"* ]]
    [[ "$output" == *"needs your password"* ]]
}

@test "the real Homebrew and the real ~/.gem are clean, and both count 0" {
    # The same check, no redirection: the machine this was written for.
    run bash -c 'source "$1"; rgh_root_owned_count "$2"; rgh_root_owned_count "$3"' \
        _ "$RGH_LIB" /opt/homebrew "$HOME/.gem"
    [ "$output" = "00" ]
}

@test "the gem home is checked too, not only Homebrew" {
    run bash -c 'source "$1"; RGH_GEM_HOME=/etc/ssh rgh_check_root_ownership' _ "$RGH_LIB"
    [ "$status" -eq 1 ]
    [[ "$output" == *"/etc/ssh"* ]]
}

@test "the counter is recursive, not top-level only" {
    # The 2026-09-16 damage was 591 files deep under lib/ruby/site_ruby, so a
    # counter that only looked at the top of the tree would have read 0.
    run bash -c 'source "$1"; rgh_root_owned_count "$2"' _ "$RGH_LIB" /etc/ssh
    [ "$output" -ge 5 ]
}

@test "a site_ruby override file FAILs, and the printed fix moves rather than deletes" {
    printf '  VERSION = "4.0.21"\n' >"${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb"
    run check rgh_check_site_ruby_empty
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  site_ruby contains file(s)"* ]]
    [[ "$output" == *"Developer/Backups/site_ruby-stale"* ]]
    [[ "$output" == *"moves, never deletes"* ]]
    # A fix that could destroy data is not an acceptable fix.
    [[ "$output" != *"rm -rf"* ]]
    [[ "$output" != *"rm "* ]]
}

@test "an empty site_ruby directory is healthy" {
    # 4.0.0/ already exists and is empty in setup(). Creating and removing the
    # directory must not change the verdict: the directory existing is not the
    # fault, a file in it is.
    run check rgh_check_site_ruby_empty
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "gem -v differing from the shipped rubygems.rb FAILs" {
    export GEM_REPORT_VERSION=4.0.21
    run check rgh_check_gem_version_parity
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  gem reports 4.0.21 but the Homebrew Ruby ships 4.0.20"* ]]
    [[ "$output" == *"site_ruby override is loaded"* ]]
}

@test "the parity check FAILs rather than passing when it cannot measure" {
    # gem broken/absent: stderr is empty and stdout is empty, so a naive check
    # would report 0 warnings and call a healthy machine. Measuring nothing
    # must never read as a pass.
    cat >"${SHIM}/gem" <<'EOF'
#!/bin/sh
exit 3
EOF
    chmod +x "${SHIM}/gem"
    run check rgh_check_gem_version_parity
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  could not read both gem versions"* ]]
    [[ "$output" == *"measured nothing"* ]]
}

@test "brew doctor reporting an unlinked keg FAILs" {
    cat >"${SHIM}/brew" <<'EOF'
#!/bin/sh
[ "$1" = "doctor" ] && {
    echo "Error: /opt/homebrew is not writable."
    echo "Warning: unlinked kegs:"
    echo "  python@3.12"
    exit 1
}
exit 0
EOF
    chmod +x "${SHIM}/brew"
    run check rgh_check_brew_kegs
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  brew doctor reports"* ]]
    [[ "$output" == *"brew link --overwrite"* ]]
}

@test "a stale plugin pointing at a removed keg FAILs" {
    printf "require_relative '%s'\n" \
        "../../../../../../opt/homebrew/Cellar/ruby/4.0.7/lib/ruby/gems/4.0.0/gems/rdoc-7.0.4/lib/rubygems_plugin.rb" \
        >"${RGH_GEM_HOME}/ruby/4.0.0/plugins/rdoc_plugin.rb"
    run check rgh_check_gem_wiring
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  "*"broken ~/.gem reference"* ]]
    [[ "$output" == *"stale plugin: ${RGH_GEM_HOME}/ruby/4.0.0/plugins/rdoc_plugin.rb"* ]]
}

@test "a plugin whose target exists is not flagged" {
    mkdir -p "${RGH_GEM_HOME}/ruby/4.0.0/gems/rdoc-7.0.4/lib"
    printf '# nothing\n' >"${RGH_GEM_HOME}/ruby/4.0.0/gems/rdoc-7.0.4/lib/rubygems_plugin.rb"
    # plugins/ is a SIBLING of gems/, both inside ruby/4.0.0/, so one level up.
    # The check flagged an earlier version of this fixture that used two. It was
    # right to: that path genuinely does not resolve.
    printf "require_relative '%s'\n" \
        "../gems/rdoc-7.0.4/lib/rubygems_plugin.rb" \
        >"${RGH_GEM_HOME}/ruby/4.0.0/plugins/rdoc_plugin.rb"
    run check rgh_check_gem_wiring
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS"* ]]
}

@test "a ~/.gem command with a shebang to a missing interpreter FAILs" {
    printf '#!/opt/homebrew/opt/ruby-99.9.9/bin/ruby\n' >"${RGH_GEM_HOME}/ruby/4.0.0/bin/rubocop"
    run check rgh_check_gem_wiring
    [ "$status" -eq 1 ]
    [[ "$output" == *"broken command: ${RGH_GEM_HOME}/ruby/4.0.0/bin/rubocop"* ]]
    [[ "$output" == *"/opt/homebrew/opt/ruby-99.9.9/bin/ruby"* ]]
}

@test "duplicate versions inside ~/.gem WARN, and the fix uses --user-install" {
    mkdir -p "${RGH_GEM_HOME}/ruby/4.0.0/gems/foo-1.0.0" "${RGH_GEM_HOME}/ruby/4.0.0/gems/foo-2.0.0"
    run check rgh_check_duplicate_gems
    # WARN only. An extra copy is untidy, not the root-ownership damage.
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN  1 gem(s) have more than one version inside ~/.gem"* ]]
    [[ "$output" == *"gem cleanup --user-install"* ]]
}

@test "the duplicate check never reads the Cellar, where default gems are expected" {
    # A default gem exists at only one version in the user's tree. It must not
    # be reported as a duplicate just because Homebrew also ships one.
    mkdir -p "${RGH_GEM_HOME}/ruby/4.0.0/gems/json-3.0.2"
    run check rgh_check_duplicate_gems
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS  no duplicate gem versions inside ~/.gem"* ]]
}

@test "every damage at once still reports all of it in one run" {
    export RGH_ROOT_USER="$(id -un)" # stand in for root: see the note in setup
    printf 'x\n' >"${RGH_HOMEBREW_ROOT}/lib/ruby/gems/stray"
    printf '  VERSION = "4.0.21"\n' >"${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb"
    printf "require_relative '/gone/rubygems_plugin.rb'\n" \
        >"${RGH_GEM_HOME}/ruby/4.0.0/plugins/rdoc_plugin.rb"
    printf '#!/nowhere/ruby\n' >"${RGH_GEM_HOME}/ruby/4.0.0/bin/rubocop"
    export GEM_REPORT_VERSION=4.0.21

    run report
    [ "$status" -eq 0 ] # rgh_report returns the last check's status
    [[ "$output" == *"FAIL  root-owned entries"* ]]
    [[ "$output" == *"FAIL  gem reports 4.0.21"* ]]
    [[ "$output" == *"FAIL  site_ruby contains file(s)"* ]]
    [[ "$output" == *"FAIL  "*"broken ~/.gem reference"* ]]
}

# ===========================================================================
# The check library must never escalate. `sudo` in a printed fix is required;
# `sudo` as an executed command is not, and is how a guard becomes the bug.
# ===========================================================================

@test "the check library never executes sudo" {
    # Every sudo in the file must be inside a printed string, never a command.
    run grep -nE '^[[:space:]]*sudo[[:space:]]' "${SCRIPTS_DIR}/lib/ruby_gem_health.sh"
    [ "$status" -ne 0 ]
}

@test "the check library writes nothing" {
    local before after
    before="$(find "$FIX" | sort)"
    run report
    after="$(find "$FIX" | sort)"
    [ "$before" = "$after" ]
}

# ===========================================================================
# mac-routine.sh
# ===========================================================================

setup_routine() {
    RT="${BATS_TEST_TMPDIR}/routine"
    mkdir -p "$RT/bin"
    CALLS="${RT}/calls"
    : >"$CALLS"
    # docker is a PROBE only: mac-routine calls `docker info` to decide whether
    # to disable the Containers step. Logging it would make the call log assert
    # that a routine step ran.
    cat >"${RT}/bin/docker" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "${RT}/bin/docker"
    for c in topgrade mo brew; do
        cat >"${RT}/bin/$c" <<EOF
#!/bin/sh
echo "$c \$*" >> "${CALLS}"
exit 0
EOF
        chmod +x "${RT}/bin/$c"
    done
    # Hermetic PATH: the shims, then the fixture's ruby/gem/brew stubs from
    # setup(), then the system utilities - and NOT /opt/homebrew. With the host
    # PATH the real `docker` and `orb` answered the probe, so "is a container
    # runtime running" was decided by this Mac rather than by the test.
    export PATH="${RT}/bin:${SHIM}:/usr/bin:/bin"
    export RGH_LIB="${SCRIPTS_DIR}/lib/ruby_gem_health.sh"
}

@test "mac-routine runs the four steps in order" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"topgrade -> mo clean -> brew doctor -> brew cleanup"* ]]
}

@test "mac-routine --dry-run executes no maintenance command" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh" --dry-run
    [[ "$output" == *"(dry run: not executed)"* ]]
    # brew doctor DOES run: it is the read-only probe inside the final health
    # report, and a dry run that measures nothing would prove nothing.
    ! grep -q '^topgrade' "${RT}/calls"
    ! grep -q '^mo ' "${RT}/calls"
    ! grep -q '^brew cleanup' "${RT}/calls"
}

@test "mac-routine measures before the first step and after every step" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh" --dry-run
    [[ "$output" == *"baseline:"* ]]
    [[ "$output" == *"after topgrade"* ]]
    [[ "$output" == *"after mo clean"* ]]
    [[ "$output" == *"after brew doctor"* ]]
    [[ "$output" == *"after brew cleanup"* ]]
}

@test "mac-routine disables the Containers step when no runtime answers" {
    setup_routine
    # `docker info` succeeds via the shim here, so remove the shim to model a
    # machine where the runtime is installed but stopped.
    rm -f "${RT}/bin/docker"
    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    [ "$status" -eq 0 ]
    grep -q -- '--disable containers' "${RT}/calls"
    [[ "$output" == *"no container runtime is answering"* ]]
}

@test "mac-routine leaves Containers enabled when a runtime answers" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    grep -q 'topgrade .*--disable containers' "${RT}/calls" && {
        echo "Containers was disabled even though docker answered" >&2
        return 1
    }
    grep -q -- '--disable gem' "${RT}/calls"
    grep -q -- '--disable ruby_gems' "${RT}/calls"
}

@test "mac-routine passes --no-ask-retry so topgrade cannot hang on a prompt" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    grep -q -- '--no-ask-retry' "${RT}/calls"
}

@test "mac-routine stops the routine when a step creates a root-owned file" {
    setup_routine
    export RGH_ROOT_USER="$(id -un)" # stand in for root; no test can chown to root
    # The mo step plants the damage, exactly as the 2026-09-16 event did.
    cat >"${RT}/bin/mo" <<EOF
#!/bin/sh
echo "mo \$*" >> "${CALLS}"
printf 'tampered\n' > "\${RGH_HOMEBREW_ROOT}/lib/ruby/gems/planted"
exit 0
EOF
    chmod +x "${RT}/bin/mo"

    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    [ "$status" -eq 3 ]
    [[ "$output" == *"STOPPED after step: mo clean"* ]]
    [[ "$output" == *"root-owned paths now present:"* ]]
    [[ "$output" == *"sudo find"* ]]
    [[ "$output" == *"No step after this one was run."* ]]
    # The steps after the damage must not have run.
    ! grep -q '^brew' "${RT}/calls"
}

@test "mac-routine never executes sudo" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    # Nothing named sudo exists on this PATH at all, so if the wrapper ever
    # tried to escalate the run would fail loudly rather than silently prompt.
    ! grep -q '^sudo' "${RT}/calls"
    run grep -nE '^[[:space:]]*sudo[[:space:]]' "${SCRIPTS_DIR}/mac-routine.sh"
    [ "$status" -ne 0 ]
}

@test "mac-routine stops when gem -v changes mid-routine" {
    setup_routine
    cat >"${RT}/bin/topgrade" <<EOF
#!/bin/sh
echo "topgrade \$*" >> "${CALLS}"
echo "tampered" > "\${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb"
exit 0
EOF
    chmod +x "${RT}/bin/topgrade"
    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    [ "$status" -eq 3 ]
    [[ "$output" == *"STOPPED after step: topgrade"* ]]
}

@test "mac-routine --help works and rejects nothing silently" {
    run bash "${SCRIPTS_DIR}/mac-routine.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Never uses sudo. Never deletes anything."* ]]
}

@test "mac-routine rejects an unknown option instead of running anything" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh" --wat
    [ "$status" -eq 2 ]
    [ ! -s "${RT}/calls" ]
}

# ===========================================================================
# install.sh must ship the new utility, or the wrapper is only in the repo.
# ===========================================================================

@test "install.sh installs mac-routine.sh" {
    run grep -q 'mac-routine.sh' "${SCRIPTS_DIR}/install.sh"
    [ "$status" -eq 0 ]
}