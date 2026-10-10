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

# One awk pass per file, no subprocess per line.
#
# The previous version read the file in bash and ran up to five external
# commands per LINE - a printf|grep for the comment test, another for exempt,
# another for payload, a sed for blanking, and a final grep. Over 20 files that
# is tens of thousands of processes, and it dominated the suite's runtime.
#
# The rules are unchanged and must stay unchanged; only the mechanism moved:
#   1. a line starting with optional whitespace then # is a comment, skipped
#   2. a line carrying a `safety:` comment is EXEMPT, and is REPORTED so a
#      review can see every exemption without grepping for the marker
#   3. a payload line (eval/exec/any `sh -c`) keeps its quoted text, because
#      there the quotes ARE the command
#   4. every other line has its quoted spans blanked first: text inside quotes
#      is data, not a command
#   5. what survives is matched against the eight scan patterns
#
# The regexes are passed in with -v rather than written inline, because macOS
# awk (BWK, 20200816) does not accept [[:space:]] inside a literal /.../ regex,
# while the same string handed over as a variable matches correctly. Passing
# them in keeps ONE definition of each pattern, the same constant the rest of
# this file uses, so the two cannot drift.
#
# Verified by diffing this against the previous implementation's output over
# every scan target and every fixture: byte-identical.
scan_one_file() {
    awk -v file="$1" -v strip="${PROJECT_ROOT}/" \
        -v comment_re='^[[:space:]]*#' \
        -v exempt_re="$SAFETY_EXEMPT_RE" \
        -v payload_re="$SAFETY_PAYLOAD_RE" \
        -v scan_re="$SAFETY_SCAN_PATTERNS" '
    {
        line = $0
        if (line ~ comment_re) next
        if (line ~ exempt_re) {
            text = line
            sub(/^[[:space:]]+/, "", text)
            sub(/^/, "", text)
            printf "%s:%d: EXEMPT: %s\n", short, FNR, text
            next
        }
        if (line !~ payload_re) {
            gsub(/'"'"'[^'"'"']*'"'"'/, "", line)
            gsub(/"[^"]*"/, "", line)
            gsub(/`[^`]*`/, "", line)
        }
        if (line ~ scan_re) {
            text = $0
            sub(/^[[:space:]]+/, "", text)
            printf "%s:%d: %s\n", short, FNR, text
        }
    }
    function shorten(s) { sub("^" strip, "", s); return s }
    BEGIN { short = shorten(file) }
    ' "$1"
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
        # An `if`, not a `case`. A `case` inside a $( ) substitution is the one
        # construct in this suite that breaks bash 3.2, which is /bin/bash on
        # macOS; `make test-bash32` runs the suite under it.
        [ "${file##*/}" = "safety.bats" ] && continue
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
    cp "${PROJECT_ROOT}/tests/fixtures/marked-shim-names.bats" "$marked"
    # Exempt, AND listed in the output so a reviewer sees it without grepping.
    local out
    out="$(scan_one_file "$marked")"
    [[ "$out" == *"marked.bats:2: EXEMPT: for c in sudo gem"* ]]

    # A bare `safety:` in the MIDDLE of the line is not an exemption.
    local midmarker="${dir}/midmarker.bats"
    cp "${PROJECT_ROOT}/tests/fixtures/midmarker.bats" "$midmarker"
    out="$(scan_violations "$midmarker")"
    [[ "$out" == *"midmarker.bats:2:"* ]]

    # The same line WITHOUT the marker IS a finding. Proves the exemption is
    # the marker and not a general blind spot around these names.
    local unmarked="${dir}/unmarked.bats"
    cp "${PROJECT_ROOT}/tests/fixtures/unmarked.bats" "$unmarked"
    out="$(scan_violations "$unmarked")"
    [[ "$out" == *"unmarked.bats:2:"* ]]
}

@test "static scan: it catches a planted line, reported as file:line" {
    # Proven against a TEMP COPY. Nothing is ever planted in the repository.
    local dir="${BATS_TEST_TMPDIR}/planted"
    mkdir -p "$dir/tests" "$dir/scripts/lib"
    local bad="${dir}/tests/planted.bats"
    cp "${PROJECT_ROOT}/tests/fixtures/planted-command.bats" "$bad"
    local out
    out="$(scan_violations "$bad")"
    [ -n "$out" ]
    [[ "$out" == *"planted.bats:4:"* ]]
    [[ "$out" == *"gem update --system"* ]]

    local bad2="${dir}/scripts/planted.sh"
    cp "${PROJECT_ROOT}/tests/fixtures/planted-sudo-gem.sh" "$bad2"
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
    cp "${PROJECT_ROOT}/tests/fixtures/abspath.bats" "$f"
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
    cp "${PROJECT_ROOT}/tests/fixtures/named.bats" "$named"
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
    cp "${PROJECT_ROOT}/tests/fixtures/payload.bats" "$f"
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
    cp "${PROJECT_ROOT}/tests/fixtures/payload-marked.bats" "$marked"
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
    cp "${PROJECT_ROOT}/tests/fixtures/clean-quoted.bats" "$f"
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
    sed "s|__FILE__|${dir}/f|" "${PROJECT_ROOT}/tests/fixtures/mid-test-negation.bats" >"$t"
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
    sed "s|__FILE__|${dir}/f|" "${PROJECT_ROOT}/tests/fixtures/enforced-must-fail.bats" >"$t"
    run bats "$t"
    [ "$status" -ne 0 ]

    # And it passes when it should, so it is not failing for an unrelated reason.
    printf 'nothing here\n' >"${dir}/g"
    sed "s|__FILE__|${dir}/g|" "${PROJECT_ROOT}/tests/fixtures/enforced-must-pass.bats" >"$t"
    run bats "$t"
    [ "$status" -eq 0 ]
}

@test "static scan: the bare-negation scanner catches a planted one" {
    # Proved to fail, like every other check here.
    local dir="${BATS_TEST_TMPDIR}/negscan"
    mkdir -p "$dir"
    local f="${dir}/planted.bats"
    cp "${PROJECT_ROOT}/tests/fixtures/negscan-planted.bats" "$f"
    local out
    out="$(scan_bare_negations "$f")"
    [[ "$out" == *"planted.bats:4:"* ]]
    [[ "$out" == *"! grep -q x /dev/null"* ]]

    local clean="${dir}/clean.bats"
    cp "${PROJECT_ROOT}/tests/fixtures/negscan-clean.bats" "$clean"
    [ -z "$(scan_bare_negations "$clean")" ]
}
# ---------------------------------------------------------------------------
# Duplicate @test names.
#
# bats refuses to run a file that declares the same test name twice, but only
# some versions check it. Local bats is 1.14.0 and ran this file happily with
# four tests all called "planted"; CI on bats 1.10.0 stopped dead with
#   Error: Duplicate test name(s) in file ".../tests/safety.bats":
#          test_planted test_planted test_planted
# so the same source passed on one machine and failed on the other. This scan
# counts EVERY @test line in the file - including the ones inside heredocs,
# which is where all four "planted" names lived - so the class of failure is
# caught whatever version runs it.
#
# safety.bats is NOT excluded from its own scan. It is the file that had the
# duplicates.
# ---------------------------------------------------------------------------

# Prints "<file>:<line>: DUPLICATE @test name <n> times: <name>" for each name
# declared more than once in one file. Sort the output; awk's `for (n in ...)`
# has no defined order and a test that reported failures in a random order is
# a test nobody can read.
scan_duplicate_test_names() {
    awk '
        match($0, /^[[:space:]]*@test[[:space:]]/) {
            rest = substr($0, RSTART + RLENGTH)
            sub(/^[[:space:]]+/, "", rest)
            if (match(rest, /^"[^"]*"/)) {
                name = substr(rest, RSTART + 1, RLENGTH - 2)
            } else {
                split(rest, parts, /[[:space:]]+/)
                name = parts[1]
            }
            count[name]++
            if (!(name in first)) first[name] = FNR
        }
        END {
            for (n in count) {
                if (count[n] > 1) {
                    printf "%s:%s: DUPLICATE @test name %d times: %s\n",
                           FILENAME, first[n], count[n], n
                }
            }
        }
    ' "$1" | sort
}

@test "static scan: no two tests in one file share an @test name" {
    local file hits offenders=""
    for file in "${PROJECT_ROOT}"/tests/*.bats; do
        [ -f "$file" ] || continue
        hits="$(scan_duplicate_test_names "$file")"
        [ -n "$hits" ] || continue
        offenders="${offenders}${hits}"$'\n'
    done
    offenders="${offenders%$'\n'}"
    if [ -n "$offenders" ]; then
        echo "Duplicate @test names. bats 1.10.0 refuses to run a file that declares one twice:" >&2
        printf '%s\n' "$offenders" | sed 's/^/  /' >&2
        return 1
    fi
}

@test "static scan: the duplicate-name scanner catches a planted duplicate" {
    # Written with printf, not a heredoc on purpose. bats rewrites `@test`
    # occurrences textually when it LOADS a .bats file, and that pass reaches
    # heredoc bodies too, so a fixture written from a heredoc has already had
    # its `@test` lines rewritten by the time a scan could read it. printf
    # builds the text at run time, after that pass.
    local dir="${BATS_TEST_TMPDIR}/dupnames"
    mkdir -p "$dir"
    local f="${dir}/dup.bats"
    printf '@test "same name" {\n    true\n}\n@test "same name" {\n    true\n}\n' >"$f"
    local out
    out="$(scan_duplicate_test_names "$f")"
    [[ "$out" == *"DUPLICATE @test name 2 times: same name"* ]]

    # Three is the case CI actually hit.
    printf '@test "a" {\n    true\n}\n@test "b" {\n    true\n}\n@test "a" {\n    true\n}\n@test "b" {\n    true\n}\n' >"$f"
    out="$(scan_duplicate_test_names "$f")"
    [[ "$out" == *"DUPLICATE @test name 2 times: a"* ]]
    [[ "$out" == *"DUPLICATE @test name 2 times: b"* ]]

    # A clean file reports nothing, so the check above is not just always-on.
    local clean="${dir}/clean.bats"
    printf '@test "one" {\n    true\n}\n@test "two" {\n    true\n}\n' >"$clean"
    [ -z "$(scan_duplicate_test_names "$clean")" ]

    # And the scan really is reading the file: a name that appears once is not
    # reported even though it sits among the others.
    printf '@test "solo" {\n    true\n}\n@test "solo" {\n    true\n}\n@test "unique" {\n    true\n}\n' >"$f"
    out="$(scan_duplicate_test_names "$f")"
    [[ "$out" != *"unique"* ]]
}

# ---------------------------------------------------------------------------
# No @test text inside a heredoc.
#
# CI (bats 1.10.0) refused to run this file because four fixture heredocs each
# declared `@test "planted"`. They were TEXT - files this suite writes to a temp
# dir so the scanner can read them - and bats 1.14.0 correctly ignores @test
# lines inside a heredoc body. Older bats counts them.
#
# Two rules keep that from coming back, and both are checked here:
#   1. every @test line in tests/*.bats starts at column 0
#   2. no @test line sits inside a heredoc body
#
# Rule 1 alone is not enough, and that is worth being explicit about: the four
# offending lines were ALREADY at column 0, because heredoc bodies are not
# indented. Rule 2 is what actually catches them, so both are enforced here.
#
# The fixtures themselves now live in tests/fixtures/*.bats as ordinary files,
# copied into BATS_TEST_TMPDIR by the tests that scan them.
# ---------------------------------------------------------------------------

# Prints "<file>:<line>: <text>" for every @test line that is indented.
#
# awk rather than `grep -nE ... "$1" | sed`: grep given a single file does NOT
# prefix the filename, so its output was "5: ...", not "path/indented.bats:5:",
# and every assertion on this function failed for that reason alone. awk also
# exits 0 on a file with no matches, which is the clean case here.
scan_indented_test_names() {
    awk -v f="$1" '/^[[:space:]]+@test[[:space:]]/ { printf "%s:%d: %s\n", f, FNR, $0 }' "$1"
}

# Prints "<file>:<line>: <text>" for every @test line inside a heredoc body.
scan_heredoc_test_names() {
    awk '
        /<<'"'"'?[A-Za-z_]/ {
            rest = $0
            sub(/.*<<[[:space:]]*/, "", rest)
            gsub(/'"'"'/, "", rest)
            split(rest, a, /[[:space:]]/)
            delim = a[1]
            inh = 1
            next
        }
        inh && $0 == delim { inh = 0; next }
        inh && /^[[:space:]]*@test[[:space:]]/ { print FILENAME ":" FNR ": " $0 }
    ' "$1"
}

@test "static scan: every @test line starts at column 0, and none is inside a heredoc" {
    local file hits offenders=""
    for file in "${PROJECT_ROOT}"/tests/*.bats; do
        [ -f "$file" ] || continue
        hits="$(scan_indented_test_names "$file")"
        [ -n "$hits" ] || continue
        offenders="${offenders}${hits}"$'\n'
    done
    offenders="${offenders%$'\n'}"
    if [ -n "$offenders" ]; then
        echo "Indented @test lines. Every @test must start at column 0:" >&2
        printf '%s\n' "$offenders" | sed 's/^/  /' >&2
        return 1
    fi

    for file in "${PROJECT_ROOT}"/tests/*.bats; do
        [ -f "$file" ] || continue
        hits="$(scan_heredoc_test_names "$file")"
        [ -n "$hits" ] || continue
        offenders="${offenders}${hits}"$'\n'
    done
    offenders="${offenders%$'\n'}"
    if [ -n "$offenders" ]; then
        echo "@test text inside a heredoc. Move the fixture to tests/fixtures/:" >&2
        printf '%s\n' "$offenders" | sed 's/^/  /' >&2
        return 1
    fi
}

@test "static scan: the column-0 and heredoc scanners catch planted violations" {
    local dir="${BATS_TEST_TMPDIR}/col0"
    mkdir -p "$dir"

    # Indented, outside any heredoc. It is line 5: the three lines of the real
    # test above it push it down.
    local indented="${dir}/indented.bats"
    printf '#!/usr/bin/env bats\n@test "fine" {\n    true\n}\n    @test "indented" {\n    true\n}\n' >"$indented"
    local out
    out="$(scan_indented_test_names "$indented")"
    [[ "$out" == *"indented.bats:5:"* ]]

    # At column 0 but inside a heredoc: the shape CI rejected. It is line 6.
    # Column 0 alone does not catch this, which is why the heredoc rule exists.
    local heredoc="${dir}/heredoc.bats"
    printf '#!/usr/bin/env bats\n@test "real" {\n    true\n}\ncat >/dev/null <<%sINNER\n@test "inside" {\n    true\n}\nINNER\n' "'" >"$heredoc"
    out="$(scan_heredoc_test_names "$heredoc")"
    [[ "$out" == *"heredoc.bats:6:"* ]]

    # And a clean file trips neither, so neither check is always-on.
    local clean="${dir}/clean.bats"
    printf '#!/usr/bin/env bats\n@test "only" {\n    true\n}\n' >"$clean"
    [ -z "$(scan_indented_test_names "$clean")" ]
    [ -z "$(scan_heredoc_test_names "$clean")" ]
}
