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

    # TWO rubygems.rb files, because that is the whole point of the parity check.
    #
    # rubylibdir stands for the stdlib copy inside the keg - what Homebrew
    # SHIPS, and what site_ruby cannot shadow. The fake `ruby` reports that
    # path, exactly as `RbConfig::CONFIG["rubylibdir"]` does on the real
    # machine.
    #
    # site_ruby/4.0.0 is where a `gem update --system` writes its own
    # rubygems.rb. The fake `gem -v` follows whichever one is loaded, and
    # site_ruby sits earlier in $LOAD_PATH (measured: index 1 vs 6), so an
    # override there is what `gem -v` reports. That is precisely the situation
    # that made the old check compare a value against itself.
    mkdir -p "${FIX}/rubylibdir"
    printf '  VERSION = "4.0.20"\n' >"${FIX}/rubylibdir/rubygems.rb"
    cat >"${SHIM}/ruby" <<EOF
#!/bin/sh
[ "\$1" = "-e" ] && echo "${FIX}/rubylibdir/rubygems.rb"
exit 0
EOF
    cat >"${SHIM}/gem" <<EOF
#!/bin/sh
if [ "\$1" = "-v" ]; then
    if [ -n "\${GEM_REPORT_VERSION:-}" ]; then
        echo "\${GEM_REPORT_VERSION}"
    elif [ -r "\${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb" ]; then
        grep -m1 -E '^[[:space:]]*VERSION' "\${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb" |
            sed -E 's/.*"([^"]+)".*/\\1/'
    else
        grep -m1 -E '^[[:space:]]*VERSION' "${FIX}/rubylibdir/rubygems.rb" |
            sed -E 's/.*"([^"]+)".*/\\1/'
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

@test "rgh_report exits non-zero when only the FIRST check fails" {
    # The precise regression: rgh_report returned the LAST check's status, and
    # the last check is the INFO shebang line, which always succeeds. Damaging
    # only the ownership check therefore produced correct verdicts and a
    # misleading exit 0.
    export RGH_ROOT_USER="$(id -un)" # stand in for root; see the note in setup
    printf 'tampered\n' >"${RGH_HOMEBREW_ROOT}/lib/ruby/gems/stray"

    run report
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  root-owned entries"* ]]
    # Everything else must still have run: one FAIL may not hide the rest.
    [[ "$output" == *"PASS  gem 4.0.20 matches"* ]]
    [[ "$output" == *"PASS  no duplicate gem versions"* ]]
    # The fixture has no commands in bin/, so the last check prints its empty
    # variant. Either way, seeing an INFO line proves it ran.
    [[ "$output" == *"INFO  no ~/.gem/ruby/*/bin commands to report"* ]]
}

@test "rgh_report exits 0 when every check passes" {
    run report
    [ "$status" -eq 0 ]
}

@test "the shebang target is reported as INFO, never FAIL" {
    # A REAL interpreter this test creates itself, so the check does not depend
    # on Homebrew being installed. It used to name
    # /opt/homebrew/opt/ruby/bin/ruby, which only exists on a Mac with Homebrew.
    local interpreter="${BATS_TEST_TMPDIR}/fake-ruby"
    printf '#!/bin/sh\nexit 0\n' >"$interpreter"
    chmod +x "$interpreter"
    printf '#!%s\n' "$interpreter" >"${RGH_GEM_HOME}/ruby/4.0.0/bin/rubocop"
    run report
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO  ~/.gem/ruby/*/bin shebang target(s):"* ]]
    [[ "$output" == *"$interpreter"* ]]
    [[ "$output" != *"FAIL  "* ]]
}

@test "a shebang pointing at a MISSING interpreter FAILs" {
    # The other half of the pair above, and its own test on purpose: an INFO
    # check that is never seen to FAIL is not known to be able to.
    local missing="${BATS_TEST_TMPDIR}/no-such-ruby"
    printf '#!%s\n' "$missing" >"${RGH_GEM_HOME}/ruby/4.0.0/bin/rubocop"
    run report
    [ "$status" -eq 1 ]
    [[ "$output" == *"broken command:"* ]]
    [[ "$output" == *"$missing"* ]]
    [[ "$output" == *"FAIL  "* ]]
}

# ===========================================================================
# FAKE FIXTURE: reproduce each piece of the 2026-09-16 damage and prove the
# matching check turns FAIL, with the fix command in the output.
# ===========================================================================

# Builds a directory tree owned by the CURRENT user and points RGH_ROOT_USER at
# that same user, which is how this file already fakes root ownership (see the
# RGH_ROOT_USER uses in the routine tests below). No test can chown to real root,
# and no test needs a system directory to already be root-owned.
#
# This replaces /etc/ssh, which the earlier version of these four tests used. It
# is root-owned on the development Mac - exactly 7 entries, measured, and the
# count was hardcoded in the assertion - but it does not exist on the Ubuntu CI
# runner, where `find` counted 0 and the tests failed for a reason that had
# nothing to do with the check they were meant to cover.
make_owned_tree() {
    local root="$1"
    mkdir -p "${root}/a/b/c"
    : >"${root}/top"
    : >"${root}/a/one"
    : >"${root}/a/b/two"
    : >"${root}/a/b/c/three"
    # 8 entries: the root itself, a, a/b, a/b/c, and the four files.
    export RGH_ROOT_USER="$(id -un)"
}

@test "a tree owned by the stand-in root FAILs the ownership check, with the fix printed" {
    local tree="${BATS_TEST_TMPDIR}/owned-tree"
    make_owned_tree "$tree"
    RGH_HOMEBREW_ROOT="$tree" run check rgh_check_root_ownership
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  root-owned entries"* ]]
    # The count is measured by this test from the tree it just built, not
    # copied from another machine.
    local expected
    expected="$(find "$tree" -user "$(id -un)" | wc -l | tr -d ' ')"
    [ "$expected" -ge 8 ]
    [[ "$output" == *"$expected"* ]]
    # The fix is printed, never run, and carries the password caveat.
    [[ "$output" == *"sudo find $tree -user root -exec chown"* ]]
    [[ "$output" == *"needs your password"* ]]
}

@test "the gem home is checked too, not only Homebrew" {
    local tree="${BATS_TEST_TMPDIR}/gem-owned-tree"
    make_owned_tree "$tree"
    # Homebrew root deliberately left empty, so the failure can only come from
    # the gem home. That is the property under test.
    run bash -c 'source "$1"; RGH_ROOT_USER="$2"; RGH_HOMEBREW_ROOT="$3"; RGH_GEM_HOME="$4" rgh_check_root_ownership' \
        _ "$RGH_LIB" "$(id -un)" "${BATS_TEST_TMPDIR}/empty-root" "$tree"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$tree"* ]]
}

@test "the counter is recursive, not top-level only" {
    # The 2026-09-16 damage was 591 files deep under lib/ruby/site_ruby, so a
    # counter that only looked at the top of the tree would have read 0.
    local tree="${BATS_TEST_TMPDIR}/deep-tree"
    make_owned_tree "$tree"
    run bash -c 'source "$1"; RGH_ROOT_USER="$2"; rgh_root_owned_count "$3"' \
        _ "$RGH_LIB" "$(id -un)" "$tree"
    local counted top_only
    counted="$output"
    # Exactly the top-level entry is what a non-recursive counter would report.
    top_only="$(find "$tree" -maxdepth 0 -user "$(id -un)" | wc -l | tr -d ' ')"
    [ "$top_only" -eq 1 ]
    [ "$counted" -gt "$top_only" ]
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

@test "an override installed in site_ruby is caught, not compared against itself" {
    # The regression this fixes, stated as a test.
    #
    # The fixture's fake `ruby` answers the rubylibdir probe with the SHIPPED
    # copy (4.0.20). The fake `gem -v` follows whichever rubygems.rb is loaded,
    # and site_ruby sits earlier in $LOAD_PATH - measured on the real machine as
    # index 1 against rubylibdir's index 6 - so it reports the OVERRIDE.
    #
    # The old implementation read the shipped version out of the LOADED file,
    # which made both sides of the comparison identical and the check
    # incapable of failing. Here the two genuinely differ and it FAILs.
    printf '  VERSION = "4.0.21"\n' \
        >"${RGH_HOMEBREW_ROOT}/lib/ruby/site_ruby/4.0.0/rubygems.rb"

    run check rgh_check_gem_version_parity
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL  gem reports 4.0.21 but the Homebrew Ruby ships 4.0.20"* ]]
    [[ "$output" == *"site_ruby override is loaded"* ]]
}

@test "no override means the two versions agree and the check PASSes" {
    run check rgh_check_gem_version_parity
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASS  gem 4.0.20 matches"* ]]
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
    # Non-zero: rgh_report returns the OR of every check, so one FAIL is enough.
    # It used to return only the LAST check's status, and the last check is an
    # INFO line that always succeeds - a false all-clear for the caller.
    [ "$status" -eq 1 ]
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

# Fails loudly if any protected binary reachable on PATH is not the suite-wide
# fake or one of this file's own shims. Split out of setup_routine so it can be
# pointed at a BAD PATH and seen to fail - a guard that has never failed is not
# known to work.
assert_protected_tools_fake() {
    local _tool _resolved
    for _tool in sudo gem brew; do # safety: shim names, not a command
        _resolved="$(command -v "$_tool" || printf '<not found>')"
        if ! is_fake_path "$_resolved"; then
            printf 'UNSAFE PATH: %s resolves to %s\n' "$_tool" "$_resolved" >&2
            printf '  expected a path under %s, %s or %s/bin\n' \
                "$FAKE_BIN_DIR" "$SHIM" "$RT" >&2
            return 1
        fi
    done
}

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
    # setup(), then the suite-wide fake bin from test_helper, then the system
    # utilities - and NOT /opt/homebrew. With the host
    # PATH the real `docker` and `orb` answered the probe, so "is a container
    # runtime running" was decided by this Mac rather than by the test.
    #
    # ${FAKE_BIN_DIR} is the part that is easy to lose. ${RT}/bin and ${SHIM}
    # supply topgrade, mo, brew, ruby and gem, and NEITHER supplies sudo. This
    # line used to end at /usr/bin, which reset PATH and dropped the fence
    # test_helper installed, so sudo fell through to the real /usr/bin/sudo -
    # the one thing these tests must never reach.
    export PATH="${RT}/bin:${SHIM}:${FAKE_BIN_DIR}:/usr/bin:/bin"
    export RGH_LIB="${SCRIPTS_DIR}/lib/ruby_gem_health.sh"

    # Assert the fence here rather than in each test, so every test in this file
    # inherits it and a broken PATH fails once, loudly, instead of quietly in
    # whichever test happened to reach a protected binary first.
    assert_protected_tools_fake
}

@test "setup_routine's PATH guard fires on a PATH that reaches the real binaries" {
    setup_routine
    # Positive: the PATH setup_routine built is safe.
    assert_protected_tools_fake

    # Negative, in a subshell so a bad PATH cannot leak into anything after it.
    # `command -v` only resolves a name; it does not run the binary.
    if (
        export PATH="/opt/homebrew/bin:/usr/bin:/bin"
        assert_protected_tools_fake
    ); then
        echo "the guard accepted the real binaries" >&2
        return 1
    fi

    # And the fences the wrapper relies on are the ones actually in place.
    [[ "$(command -v sudo)" == "${FAKE_BIN_DIR}/sudo" ]]
    [[ "$(command -v brew)" == "${RT}/bin/brew" ]]
    [[ "$(command -v gem)" == "${SHIM}/gem" ]]
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
    run grep -q '^topgrade' "${RT}/calls"
    [ "$status" -ne 0 ]
    run grep -q '^mo ' "${RT}/calls"
    [ "$status" -ne 0 ]
    run grep -q '^brew cleanup' "${RT}/calls"
    [ "$status" -ne 0 ]
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
    # Model a machine where a runtime is installed but STOPPED, by putting
    # failing shims FIRST on PATH - not by removing the working one.
    #
    # The previous version deleted ${RT}/bin/docker and then relied on the
    # runner happening to have no docker anywhere. On a runner that does have
    # one, the test asserted nothing. Deleting is also not something a test in
    # this suite should do.
    local dead="${RT}/not-running"
    mkdir -p "$dead"
    local rt
    for rt in docker podman orb orbctl; do
        printf '#!/bin/sh\nexit 1\n' >"${dead}/${rt}"
        chmod +x "${dead}/${rt}"
    done
    export PATH="${dead}:${PATH}"
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
    run grep -q '^brew' "${RT}/calls"
    [ "$status" -ne 0 ]
}

@test "mac-routine never executes sudo" {
    setup_routine
    run bash "${SCRIPTS_DIR}/mac-routine.sh"
    # Nothing named sudo is provided by ${RT}/bin or ${SHIM}, so `sudo` here
    # resolves to the suite-wide fake: a recorder that exits 0. The wrapper must
    # therefore never call it - the fake's log stays empty.
    run grep -q '^sudo' "${RT}/calls"
    [ "$status" -ne 0 ]
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
