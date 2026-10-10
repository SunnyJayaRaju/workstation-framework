#!/usr/bin/env bats

load test_helper

# ---------------------------------------------------------------------------
# Safety tests for the test suite itself.
#
# On 2026-10-10 a test in this suite ran `gem update --sys` for real, because it
# evaluated a command string in bats' own shell where gem and sudo are the real
# binaries. 591 files landed in /opt/homebrew/lib/ruby/site_ruby. These two
# tests exist so that class of accident cannot come back.
#
# THIS FILE IS EXCLUDED FROM ITS OWN STATIC SCAN: it necessarily contains the
# very command patterns the scan looks for.
# ---------------------------------------------------------------------------

@test "canary: gem, sudo and brew resolve to a fake, never to the real binary" {
    local tool resolved
    for tool in gem sudo brew; do
        resolved="$(command -v "$tool" || printf '<not found>')"
        if ! is_fake_path "$resolved"; then
            echo "UNSAFE: ${tool} resolves to ${resolved}" >&2
            echo "       expected a path under ${FAKE_BIN_DIR} or under ${BATS_TEST_TMPDIR}" >&2
            return 1
        fi
    done
}

@test "canary: the fakes record their calls instead of doing anything" {
    local log="${BATS_TEST_TMPDIR}/fake-calls.log"
    gem list
    sudo ls /tmp
    brew doctor
    [ -f "$log" ]
    grep -q '^gem list$' "$log"
    grep -q '^sudo ls /tmp$' "$log"
    grep -q '^brew doctor$' "$log"
}

@test "canary: the fence survives a test that prepends its own shim directory" {
    # A richer shim is allowed and must come first. This is the arrangement
    # tests/guard.bats and tests/ruby-gem-guard.bats both use.
    local own="${BATS_TEST_TMPDIR}/own-shim"
    mkdir -p "$own"
    printf '#!/bin/sh\nexit 0\n' >"${own}/gem"
    chmod +x "${own}/gem"
    local resolved
    resolved="$(PATH="${own}:${PATH}" command -v gem)"
    [[ "$resolved" == "${own}/gem" ]]
    is_fake_path "$resolved"
}

@test "canary: a resolution outside every fake is rejected" {
    # The canary's own predicate, proved to fail. A guard that has never been
    # seen to fail is not known to work.
    is_fake_path "/opt/homebrew/bin/gem" && {
        echo "is_fake_path accepted the real gem" >&2
        return 1
    }
    is_fake_path "/usr/bin/sudo" && return 1
    is_fake_path "/opt/homebrew/bin/brew" && return 1
    is_fake_path "${FAKE_BIN_DIR}/gem" || return 1
    is_fake_path "${BATS_TEST_TMPDIR}/shim/brew" || return 1
}

# ---------------------------------------------------------------------------
# Static scan. No test, and no script, may contain an executable line that
# invokes one of the four commands that can damage this machine.
#
#   gem update          installs a whole RubyGems tree into sitelibdir
#   sudo gem            the same, as root
#   sudo brew           root write into /opt/homebrew
#   brew upgrade        installs, and rewrites keg links
#
# "Executable line" is enforced, not just "the text appears": a full-line
# comment is skipped, and every single-, double- or back-quoted span is blanked
# before matching. That is what lets a test assert on the text
# "gem update --system" as a STRING while forbidding it as a COMMAND.
#
# SHIM AND RUNNER EXEMPTION. A test has to be able to build a fake sudo, so a
# line naming several of them in one breath is legitimate:
#     for c in sudo gem; do
# To exempt such a line, append the marker `safety:` to it as a comment:
#     for c in sudo gem; do # safety: shim names, not a command
# The marker is explicit and greppable, so an exemption is visible in review
# and cannot be added by accident. Nothing else is exempt.
# ---------------------------------------------------------------------------

readonly SAFETY_EXEMPT_MARKER="safety:"

readonly SAFETY_SCAN_PATTERNS='(^|[^[:alnum:]_./-])gem[[:space:]]+update|(^|[^[:alnum:]_./-])sudo[[:space:]]+gem|(^|[^[:alnum:]_./-])sudo[[:space:]]+brew|(^|[^[:alnum:]_./-])brew[[:space:]]+upgrade'

# Prints "<file>:<line>: <text>" for every offending line in stdin's file.
scan_one_file() {
    local file="$1" n=0 line stripped
    while IFS= read -r line; do
        n=$((n + 1))
        # A comment line is not an executable line.
        case "$line" in
            [[:space:]]*'#'*) continue ;;
        esac
        # An explicitly marked shim/runner line is exempt.
        case "$line" in
            *"$SAFETY_EXEMPT_MARKER"*) continue ;;
        esac
        # Blank out quoted spans: text inside quotes is data, not a command.
        stripped="$(printf '%s' "$line" |
            sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' -e 's/`[^`]*`//g')"
        if printf '%s' "$stripped" | grep -qE "$SAFETY_SCAN_PATTERNS"; then
            printf '%s:%s: %s\n' "${file#"${PROJECT_ROOT}/"}" "$n" \
                "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
        fi
    done <"$file"
}

# Every file the scan covers.
scan_targets() {
    printf '%s\n' "${PROJECT_ROOT}"/tests/*.bats
    printf '%s\n' "${PROJECT_ROOT}"/scripts/*.sh
    printf '%s\n' "${PROJECT_ROOT}"/scripts/lib/*.sh
}

@test "static scan: no test or script invokes a command that can damage this machine" {
    local file hit offenders=""
    while IFS= read -r file; do
        [ -f "$file" ] || continue
        # This file necessarily contains the patterns as literals.
        case "$file" in
            *"/tests/safety.bats") continue ;;
        esac
        # Only append when there IS a hit: appending unconditionally filled the
        # report with blank lines for every clean file.
        hit="$(scan_one_file "$file")"
        [ -n "$hit" ] && offenders="${offenders}${hit}"$'\n'
    done < <(scan_targets)
    offenders="${offenders%$'\n'}"
    if [ -n "$offenders" ]; then
        echo "Offending lines - gem update, sudo gem, sudo brew, brew upgrade:" >&2
        printf '%s\n' "$offenders" | sed 's/^/  /' >&2
        return 1
    fi
}

@test "static scan: the shim exemption is honoured, and only when marked" {
    local dir="${BATS_TEST_TMPDIR}/exempt"
    mkdir -p "$dir"
    local marked="${dir}/marked.bats"
    cat >"$marked" <<'M1'
#!/usr/bin/env bats
for c in sudo gem; do # safety: shim names, not a command
M1
    local out
    out="$(scan_one_file "$marked")"
    [ -z "$out" ]

    # The same line without the marker IS a finding. Proves the exemption is
    # the marker and not a general blind spot around these names.
    local unmarked="${dir}/unmarked.bats"
    cat >"$unmarked" <<'M2'
#!/usr/bin/env bats
for c in sudo gem; do
M2
    out="$(scan_one_file "$unmarked")"
    [[ "$out" == *"unmarked.bats:2:"* ]]
}

@test "static scan: it actually catches a planted line, reported as file:line" {
    # Proven against a TEMP COPY. Nothing is ever planted in the repository.
    local dir="${BATS_TEST_TMPDIR}/planted"
    mkdir -p "$dir/tests" "$dir/scripts/lib"
    local bad="${dir}/tests/planted.bats"
    cat >"$bad" <<'PLANTED'
#!/usr/bin/env bats
load test_helper
@test "planted" {
    run gem update --system
}
PLANTED
    local out
    out="$(scan_one_file "$bad")"
    [ -n "$out" ]
    [[ "$out" == *"planted.bats:4:"* ]]
    [[ "$out" == *"gem update --system"* ]]

    local bad2="${dir}/scripts/planted.sh"
    cat >"$bad2" <<'PLANTED2'
#!/bin/bash
sudo gem install foo
PLANTED2
    out="$(scan_one_file "$bad2")"
    [[ "$out" == *"planted.sh:2:"* ]]
    [[ "$out" == *"sudo gem install foo"* ]]
}

@test "static scan: comments and quoted strings are not flagged" {
    # The other half of the contract. A file full of the DANGEROUS text is fine
    # as long as none of it is a command; that is what lets the guard tests
    # assert on the very strings the guard refuses.
    local dir="${BATS_TEST_TMPDIR}/clean"
    mkdir -p "$dir"
    local f="${dir}/clean.bats"
    cat >"$f" <<'CLEAN'
#!/usr/bin/env bats
load test_helper
@test "asserts on the refused text" {
    # a comment mentioning gem update --system and sudo brew
    [[ "$output" == *"gem update --system"* ]]
    [[ "$output" == *"sudo brew upgrade"* ]]
    [[ "$output" == *"brew upgrade"* ]]
}
CLEAN
    local out
    out="$(scan_one_file "$f")"
    if [ -n "$out" ]; then
        echo "false positive on comments or quoted strings:" >&2
        printf '%s\n' "$out" | sed 's/^/  /' >&2
        return 1
    fi
}