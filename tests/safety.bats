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

# The exemption must live in a COMMENT. A bare `safety:` in the middle of an
# executable line is not an exemption: the line reading
#   eval "$1"; safety: whatever
# is still an eval. So the regex requires whitespace, then a `#`, then safety:.
readonly SAFETY_EXEMPT_RE='[[:space:]]#[[:space:]].*safety:'

# A line that BUILDS a command to run later: eval, exec, or any shell -c. The
# quoted text on such a line is a payload that WILL be executed, not inert data,
# so it is not blanked before matching. `run bash -c` is covered by the `bash -c`
# half.
readonly SAFETY_PAYLOAD_RE='(^|[^[:alnum:]_./-])(eval|exec)([[:space:]]|$)|(^|[^[:alnum:]_./-])(bash|sh|zsh)[[:space:]]+-c'

# Eight patterns. The first four are the command forms. The last four are the
# absolute-path forms, which the command patterns miss entirely, because the
# command is reached through a path rather than through PATH:
#   /opt/homebrew/bin/gem update --system    path + gem update
#   /opt/homebrew/bin/brew upgrade           path + brew upgrade
#   sudo /opt/homebrew/bin/gem install foo   sudo + a path ending in gem
#   sudo /usr/local/bin/brew update          sudo + a path ending in brew
readonly SAFETY_SCAN_PATTERNS='(^|[^[:alnum:]_./-])gem[[:space:]]+update|(^|[^[:alnum:]_./-])sudo[[:space:]]+gem|(^|[^[:alnum:]_./-])sudo[[:space:]]+brew|(^|[^[:alnum:]_./-])brew[[:space:]]+upgrade|(^|[^[:alnum:]_./-])/([[:alnum:]_.+-]+/)+gem[[:space:]]+update|(^|[^[:alnum:]_./-])/([[:alnum:]_.+-]+/)+brew[[:space:]]+upgrade|(^|[^[:alnum:]_./-])sudo[[:space:]]+[^[:space:]]*/gem([[:space:]]|$)|(^|[^[:alnum:]_./-])sudo[[:space:]]+[^[:space:]]*/brew([[:space:]]|$)'

# True when the line carries a `safety:` comment.
safety_is_exempt() {
    printf '%s' "$1" | grep -qE "$SAFETY_EXEMPT_RE"
}

# True when the line hands a quoted string to something that will execute it.
safety_is_payload() {
    printf '%s' "$1" | grep -qE "$SAFETY_PAYLOAD_RE"
}

# Prints "<file>:<line>: <text>" for every violation, and
# "<file>:<line>: EXEMPT: <text>" for every exempted line, so a review can see
# the exemptions without grepping for the marker.
scan_one_file() {
    local file="$1" n=0 line stripped
    while IFS= read -r line; do
        n=$((n + 1))
        # A comment line is not an executable line.
        #
        # Anchored, and that is a bug fix rather than a style choice. The first
        # version used the case pattern `[[:space:]]*'#'*`, which does NOT mean
        # "line starts with #": `*` happily matches everything up to a # ANYWHERE
        # in the line. So every line carrying a trailing comment was skipped
        # before it was ever matched, including `eval "$cmd"  # note`. The scan
        # was quietly blind to a large part of every file that uses comments,
        # which is most of them. Found only after the exemption listing was made
        # to report zero exemptions on files that demonstrably have them.
        if printf '%s' "$line" | grep -qE '^[[:space:]]*#'; then
            continue
        fi
        if safety_is_exempt "$line"; then
            printf '%s:%s: EXEMPT: %s\n' "${file#"${PROJECT_ROOT}/"}" "$n" \
                "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
            continue
        fi
        if safety_is_payload "$line"; then
            # Payload: the quotes are the command. Scanning the blanked line
            # would find nothing and pass the very line that runs it.
            stripped="$line"
        else
            # Blank out quoted spans: text inside quotes is data, not a command.
            stripped="$(printf '%s' "$line" |
                sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' -e 's/`[^`]*`//g')"
        fi
        if printf '%s' "$stripped" | grep -qE "$SAFETY_SCAN_PATTERNS"; then
            printf '%s:%s: %s\n' "${file#"${PROJECT_ROOT}/"}" "$n" \
                "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
        fi
    done <"$file"
}

# Violations only, exemptions filtered out.
#
# `|| true` is not cosmetic. grep exits 1 when it matches nothing, so without it
# `out="$(scan_violations "$f")"` FAILS the test whenever the answer is "clean"
# - the assertion fails precisely when it is correct. That is the same
# exit-status trap this file exists to catch, so it is fixed once here instead
# of at every call site.
scan_violations() {
    scan_one_file "$1" | grep -v ': EXEMPT: ' || true
}

# Every file the scan covers.
scan_targets() {
    printf '%s\n' "${PROJECT_ROOT}"/tests/*.bats
    printf '%s\n' "${PROJECT_ROOT}"/scripts/*.sh
    printf '%s\n' "${PROJECT_ROOT}"/scripts/lib/*.sh
    printf '%s\n' "${PROJECT_ROOT}"/templates/*
    printf '%s\n' "${PROJECT_ROOT}/Makefile"
}

@test "static scan: no test or script invokes a command that can damage this machine" {
    local file hit real_hit offenders="" exempt=0
    while IFS= read -r file; do
        [ -f "$file" ] || continue
        # This file necessarily contains the patterns as literals.
        case "$file" in
            *"/tests/safety.bats") continue ;;
        esac
        # Only append when there IS a hit: appending unconditionally filled the
        # report with blank lines for every clean file.
        hit="$(scan_one_file "$file")"
        [ -n "$hit" ] || continue
        real_hit="$(printf '%s\n' "$hit" | grep -v ': EXEMPT: ' || true)"
        exempt=$((exempt + $(printf '%s\n' "$hit" | grep -c ': EXEMPT: ' || true)))
        [ -n "$real_hit" ] || continue
        offenders="${offenders}${real_hit}"$'\n'
    done < <(scan_targets)
    offenders="${offenders%$'\n'}"
    # Always name the exemptions, on a clean run too. An exemption nobody looks
    # at is an exemption nobody reviews. The count is asserted so that a
    # listing which silently returns nothing fails here instead of passing
    # quietly and leaving the exemptions invisible.
    local exempt_list exempt_n=0
    exempt_list="$(scan_targets | while IFS= read -r file; do
        [ -f "$file" ] || continue
        case "$file" in
            *"/tests/safety.bats") continue ;;
        esac
        scan_one_file "$file" | grep ': EXEMPT: ' || true
    done)"
    exempt_n="$(printf '%s\n' "$exempt_list" | grep -c ': EXEMPT: ' || true)"
    echo "exempted lines (each carries a 'safety:' comment): ${exempt_n}"
    printf '%s\n' "$exempt_list"
    [ "${exempt_n:-0}" -ge 1 ]
    if [ -n "$offenders" ]; then
        echo "Offending lines - gem update, sudo gem, sudo brew, brew upgrade, and the absolute-path forms:" >&2
        printf '%s\n' "$offenders" | sed 's/^/  /' >&2
        return 1
    fi
}

@test "static scan: the shim exemption is honoured, and only as a comment" {
    local dir="${BATS_TEST_TMPDIR}/exempt"
    mkdir -p "$dir"
    local marked="${dir}/marked.bats"
    cat >"$marked" <<'M1'
#!/usr/bin/env bats
for c in sudo gem; do # safety: shim names, not a command
M1
    # Exempt, AND listed in the output so a reviewer sees it without grepping.
    local out
    out="$(scan_one_file "$marked")"
    [[ "$out" == *"marked.bats:2: EXEMPT: for c in sudo gem"* ]]

    # A bare `safety:` in the MIDDLE of the line is not an exemption.
    local midmarker="${dir}/midmarker.bats"
    cat >"$midmarker" <<'M2'
#!/usr/bin/env bats
for c in sudo gem; do safety: this marker is in the middle
M2
    out="$(scan_violations "$midmarker")"
    [[ "$out" == *"midmarker.bats:2:"* ]]

    # The same line WITHOUT the marker IS a finding. Proves the exemption is
    # the marker and not a general blind spot around these names.
    local unmarked="${dir}/unmarked.bats"
    cat >"$unmarked" <<'M3'
#!/usr/bin/env bats
for c in sudo gem; do
M3
    out="$(scan_violations "$unmarked")"
    [[ "$out" == *"unmarked.bats:2:"* ]]
}

@test "static scan: it catches a planted line, reported as file:line" {
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
    out="$(scan_violations "$bad")"
    [ -n "$out" ]
    [[ "$out" == *"planted.bats:4:"* ]]
    [[ "$out" == *"gem update --system"* ]]

    local bad2="${dir}/scripts/planted.sh"
    cat >"$bad2" <<'PLANTED2'
#!/bin/bash
sudo gem install foo
PLANTED2
    out="$(scan_violations "$bad2")"
    [[ "$out" == *"planted.sh:2:"* ]]
    [[ "$out" == *"sudo gem install foo"* ]]
}

@test "static scan: it catches an absolute-path invocation" {
    # The four command patterns all look for a bare command word, so each of
    # these walked past them. The path is the point: it is how a line names a
    # binary it is not supposed to trust.
    local dir="${BATS_TEST_TMPDIR}/abspath"
    mkdir -p "$dir"
    local f="${dir}/abspath.bats"
    cat >"$f" <<'ABSPATH'
#!/usr/bin/env bats
@test "planted" {
    run /opt/homebrew/bin/gem update --system
    run /usr/local/bin/brew upgrade
    run sudo /opt/homebrew/bin/gem install foo
    run sudo /opt/homebrew/bin/brew update
}
ABSPATH
    local out
    out="$(scan_violations "$f")"
    [[ "$out" == *"abspath.bats:3:"* ]]
    [[ "$out" == *"/opt/homebrew/bin/gem update --system"* ]]
    [[ "$out" == *"abspath.bats:4:"* ]]
    [[ "$out" == *"/usr/local/bin/brew upgrade"* ]]
    [[ "$out" == *"abspath.bats:5:"* ]]
    [[ "$out" == *"sudo /opt/homebrew/bin/gem install foo"* ]]
    [[ "$out" == *"abspath.bats:6:"* ]]
    [[ "$out" == *"sudo /opt/homebrew/bin/brew update"* ]]

    # A path that is only NAMED, not invoked, is still data.
    local named="${dir}/named.bats"
    cat >"$named" <<'NAMED'
#!/usr/bin/env bats
@test "named" {
    [[ "$output" == *"/opt/homebrew/bin/gem update"* ]]
}
NAMED
    [ -z "$(scan_violations "$named")" ]
}

@test "static scan: a quoted payload for eval is NOT blanked" {
    # The quoted string on each of these lines IS the command. Blanking quoted
    # spans made every one of them invisible, and each is the thing that runs
    # the command.
    #
    # KNOWN LIMIT, stated rather than hidden: this is a per-line scan, so it
    # cannot follow a value across lines. `local cmd="sudo gem update --system"`
    # on one line and `eval "$cmd"` on the next is NOT caught here. What catches
    # that shape is the runtime fence in test_helper - which is why both exist.
    local dir="${BATS_TEST_TMPDIR}/payload"
    mkdir -p "$dir"
    local f="${dir}/payload.bats"
    cat >"$f" <<'PAYLOAD'
#!/usr/bin/env bats
@test "planted" {
    eval "sudo gem update --system"
    run bash -c "brew upgrade"
    sh -c 'sudo /opt/homebrew/bin/gem update --system'
    zsh -c "gem update --system"
    exec "sudo /opt/homebrew/bin/brew upgrade"
}
PAYLOAD
    local out
    out="$(scan_violations "$f")"
    [[ "$out" == *"payload.bats:3:"* ]]
    [[ "$out" == *"sudo gem update --system"* ]]
    [[ "$out" == *"payload.bats:4:"* ]]
    [[ "$out" == *"brew upgrade"* ]]
    [[ "$out" == *"payload.bats:5:"* ]]
    [[ "$out" == *"payload.bats:6:"* ]]
    [[ "$out" == *"payload.bats:7:"* ]]

    # The exemption still works on a payload line, because it is a comment.
    local marked="${dir}/marked.bats"
    cat >"$marked" <<'MARKED'
#!/usr/bin/env bats
@test "assert the guard refuses this" {
    eval "gem list"
    [ "$output" = "sudo gem update --system" ] # safety: asserted as a string, never run
}
MARKED
    out="$(scan_violations "$marked")"
    [ -z "$out" ]
    # Asserted against the predicate directly rather than against scan_one_file's
    # listing, because the listing is what the NEXT test checks; checking both
    # here would only prove the same thing twice.
    sed -n '4p' "$marked" | grep -qE "$SAFETY_EXEMPT_RE"
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
    out="$(scan_violations "$f")"
    if [ -n "$out" ]; then
        echo "false positive on comments or quoted strings:" >&2
        printf '%s\n' "$out" | sed 's/^/  /' >&2
        return 1
    fi
}

@test "static scan: templates and the Makefile are covered" {
    # The scan targets list is the contract. A directory added to the repo and
    # forgotten here would be unscanned, so the list itself is asserted.
    local out
    out="$(scan_targets)"
    [[ "$out" == *"${PROJECT_ROOT}/Makefile"* ]]
    [[ "$out" == *"${PROJECT_ROOT}/templates/"* ]]

    # And a planted line in each is actually caught by that listing.
    local dir="${BATS_TEST_TMPDIR}/targets"
    mkdir -p "$dir/templates"
    printf '/opt/homebrew/bin/brew upgrade\n' >"${dir}/templates/bad.sh"
    local scanned
    scanned="$(printf '%s\n' "${dir}"/templates/* |
        while IFS= read -r file; do
            [ -f "$file" ] || continue
            scan_violations "$file"
        done)"
    [[ "$scanned" == *"templates/bad.sh:1:"* ]]
}

# ---------------------------------------------------------------------------
# Mid-test bare `!` negations.
#
# Measured on bats-core 1.14.0, with a temp file containing x and a line
# `! grep -q x file`, i.e. an assertion that MUST fail:
#
#   mid-test bare `!`  -> bats reports ok,  exit 0   (assertion is dead)
#   last-statement `!` -> bats reports not ok, exit 1 (assertion is enforced)
#
# So a bare `!` is only safe as the last statement of a test, and the moment
# anything is appended after it the whole assertion stops working - silently.
# The enforced form is `run <cmd>` followed by an explicit status test, which
# fires either way and needs no bats version gate.
# ---------------------------------------------------------------------------

# A bare `!` at the start of a statement, anywhere in tests/*.bats.
readonly SAFETY_BANG_RE='^[[:space:]]*![[:space:]]'

# Prints every bare `! ` statement in the file, as "<file>:<line>: <text>".
scan_bare_negations() {
    local file="$1" n=0 line
    while IFS= read -r line; do
        n=$((n + 1))
        printf '%s' "$line" | grep -qE "$SAFETY_BANG_RE" || continue
        printf '%s:%s: %s\n' "${file#"${PROJECT_ROOT}/"}" "$n" \
            "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
    done <"$file"
}

@test "static scan: a bare '!' negation never appears in a test" {
    # Stricter than the real rule on purpose. A bare `!` as the LAST statement
    # does work, so a scan keyed on "not last" would have to parse test bodies;
    # requiring the `run` form everywhere is one rule, always checkable, and
    # loses nothing - the enforced form reads the same and always fires.
    # safety.bats is excluded: this file has to spell the pattern out.
    local file offenders="" hits
    for file in "${PROJECT_ROOT}"/tests/*.bats; do
        case "$file" in
            *"/tests/safety.bats") continue ;;
        esac
        # Only append when there IS a hit. Appending unconditionally put one
        # blank line per file into the report, which is how the first version
        # reported 14 "offenders" that were all empty.
        hits="$(scan_bare_negations "$file")"
        [ -n "$hits" ] || continue
        offenders="${offenders}${hits}"$'\n'
    done
    offenders="${offenders%$'\n'}"
    if [ -n "$offenders" ]; then
        echo "Bare '!' negations. A mid-test bare '!' is never checked by bats:" >&2
        printf '%s\n' "$offenders" | sed 's/^/  /' >&2
        echo "Use: run <cmd>; [ \"\$status\" -ne 0 ]" >&2
        return 1
    fi
}

@test "the mid-test bare '!' really does not fail, which is why it is banned" {
    # Proves the premise of the ban rather than asserting it. If a future bats
    # starts enforcing mid-test `!`, THIS test fails and says so - at which
    # point the ban above can be relaxed deliberately.
    #
    # The exit status is the evidence. The inner test's own stdout is not: bats
    # suppresses the output of a test that passes, so there is nothing there to
    # assert on even though the echo really ran.
    local dir="${BATS_TEST_TMPDIR}/negation"
    mkdir -p "$dir"
    printf 'has x\n' >"${dir}/f"
    local t="${dir}/mid.bats"
    cat >"$t" <<EOF
#!/usr/bin/env bats
@test "mid-test bare negation that MUST fail and does not" {
    ! grep -q x "${dir}/f"
    echo "reached the statement AFTER the bare !"
}
EOF
    run bats "$t"
    [ "$status" -eq 0 ]
}

@test "the enforced form DOES fail when it should" {
    # The positive control for the test above: the same assertion written the
    # way this suite now writes it, against a file that contains x, must fail.
    local dir="${BATS_TEST_TMPDIR}/negation"
    mkdir -p "$dir"
    printf 'has x\n' >"${dir}/f"
    local t="${dir}/enforced.bats"
    cat >"$t" <<EOF
#!/usr/bin/env bats
@test "enforced form that MUST fail" {
    run grep -q x "${dir}/f"
    [ "\$status" -ne 0 ]
}
EOF
    run bats "$t"
    [ "$status" -ne 0 ]

    # And it passes when it should, so it is not failing for an unrelated reason.
    printf 'nothing here\n' >"${dir}/g"
    cat >"$t" <<EOF
#!/usr/bin/env bats
@test "enforced form that must pass" {
    run grep -q x "${dir}/g"
    [ "\$status" -ne 0 ]
}
EOF
    run bats "$t"
    [ "$status" -eq 0 ]
}

@test "static scan: the bare-negation scanner catches a planted one" {
    # Proved to fail, like every other check here.
    local dir="${BATS_TEST_TMPDIR}/negscan"
    mkdir -p "$dir"
    local f="${dir}/planted.bats"
    cat >"$f" <<'PLANTED'
#!/usr/bin/env bats
@test "planted" {
    echo hi
    ! grep -q x /dev/null
}
PLANTED
    local out
    out="$(scan_bare_negations "$f")"
    [[ "$out" == *"planted.bats:4:"* ]]
    [[ "$out" == *"! grep -q x /dev/null"* ]]

    local clean="${dir}/clean.bats"
    cat >"$clean" <<'CLEAN'
#!/usr/bin/env bats
@test "clean" {
    run grep -q x /dev/null
    [ "$status" -ne 0 ]
}
CLEAN
    [ -z "$(scan_bare_negations "$clean")" ]
}