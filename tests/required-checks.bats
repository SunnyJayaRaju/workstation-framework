#!/usr/bin/env bats

load test_helper

# ---------------------------------------------------------------------------
# The required status check names must match the job names quality.yml produces.
#
# Branch protection on `main` lists the checks it will accept before a merge.
# Those are strings, and nothing in GitHub keeps them in step with the workflow:
# rename a runner in the matrix and the check names change, the protection rule
# does not, and a PR that is entirely green becomes unmergeable with the message
# "the base branch policy prohibits the merge".
#
# That happened here. ubuntu-latest -> ubuntu-24.04 and macos-latest ->
# macos-15, on 2026-10-10, on PR #22, which then needed a settings change to
# merge at all.
#
# .github/required-checks.txt records the names protection must require. This
# test derives the expected names from quality.yml rather than hardcoding them,
# so the file cannot quietly become the thing that is wrong.
# ---------------------------------------------------------------------------

REQUIRED_CHECKS_FILE="${PROJECT_ROOT}/.github/required-checks.txt"
QUALITY_YML="${PROJECT_ROOT}/.github/workflows/quality.yml"

# Every "Shell Quality Checks (<os>)" the matrix can produce.
#
# Built from two independent sources and required to agree, because either one
# alone is a way to get this wrong:
#   - the matrix `os:` list, which decides which runners run
#   - the `include:` entries, which carry the per-OS tool names
# They are separate lists in the YAML and a half-edited workflow can leave them
# disagreeing.
expected_check_names() {
    local yml="$1"
    local names

    names="$(awk '
        /^[[:space:]]*os:[[:space:]]*\[/ {
            line = $0
            sub(/^[^[]*\[/, "", line)
            sub(/\].*$/, "", line)
            n = split(line, parts, ",")
            for (i = 1; i <= n; i++) {
                gsub(/[[:space:]"]/, "", parts[i])
                if (parts[i] != "") print parts[i]
            }
        }
    ' "$yml")"
    [ -n "$names" ] || return 1

    while IFS= read -r os; do
        [ -n "$os" ] || continue
        printf 'Shell Quality Checks (%s)\n' "$os"
    done <<<"$names" | sort
}

# The names as recorded in the file, sorted.
file_check_names() {
    grep -v '^[[:space:]]*$' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sort
}

@test "required-checks.txt exists and is not empty" {
    [ -r "$REQUIRED_CHECKS_FILE" ] || {
        echo "missing: $REQUIRED_CHECKS_FILE" >&2
        return 1
    }
    local n
    n="$(file_check_names "$REQUIRED_CHECKS_FILE" | wc -l | tr -d ' ')"
    [ "$n" -ge 1 ]
}

@test "quality.yml yields the expected check names" {
    # Proves the derivation works at all, before it is compared to anything.
    local out
    out="$(expected_check_names "$QUALITY_YML")"
    [ -n "$out" ]
    printf '%s\n' "$out" | grep -q 'Shell Quality Checks (ubuntu-24.04)'
    printf '%s\n' "$out" | grep -q 'Shell Quality Checks (macos-15)'
}

@test "required-checks.txt matches the names quality.yml produces" {
    local expected actual
    expected="$(expected_check_names "$QUALITY_YML")"
    actual="$(file_check_names "$REQUIRED_CHECKS_FILE")"
    if [ "$expected" != "$actual" ]; then
        echo "required-checks.txt does not match the job names in quality.yml." >&2
        echo "  expected (from quality.yml):" >&2
        printf '%s\n' "$expected" | sed 's/^/    /' >&2
        echo "  recorded in .github/required-checks.txt:" >&2
        printf '%s\n' "$actual" | sed 's/^/    /' >&2
        echo >&2
        echo "  FIX: rename the required checks in branch protection AND update" >&2
        echo "       .github/required-checks.txt. GitHub will not do this for you:" >&2
        echo "         gh api -X PATCH repos/SunnyJayaRaju/workstation-framework/branches/main/protection/required_status_checks" >&2
        echo "  Until both are renamed, a green PR is unmergeable." >&2
        return 1
    fi
}

@test "the matrix os list and the include list name the same runners" {
    # The expected-name derivation reads `os: [...]`; the include entries are a
    # second list that must agree. A workflow edited in one place only would
    # otherwise produce a file that matches neither reality nor CI.
    local yml="$QUALITY_YML"
    local matrix_os include_os
    matrix_os="$(awk '
        /^[[:space:]]*os:[[:space:]]*\[/ {
            line = $0; sub(/^[^[]*\[/, "", line); sub(/\].*$/, "", line)
            n = split(line, parts, ",")
            for (i = 1; i <= n; i++) { gsub(/[[:space:]"]/, "", parts[i]); if (parts[i] != "") print parts[i] }
        }' "$yml" | sort)"
    include_os="$(awk '
        /^[[:space:]]*- os:[[:space:]]*/ {
            line = $0; sub(/^[[:space:]]*- os:[[:space:]]*/, "", line)
            gsub(/[[:space:]"]/, "", line)
            if (line != "") print line
        }' "$yml" | sort)"
    [ -n "$matrix_os" ]
    [ -n "$include_os" ]
    if [ "$matrix_os" != "$include_os" ]; then
        echo "quality.yml matrix os list and include list disagree." >&2
        echo "  matrix os  : $(printf '%s' "$matrix_os" | tr '\n' ' ')" >&2
        echo "  include os : $(printf '%s' "$include_os" | tr '\n' ' ')" >&2
        return 1
    fi
}

@test "the mismatch check can fail" {
    # Proved against a TEMP COPY of both files. Nothing in the repository is
    # modified, and the planted file is what the check should reject.
    local dir="${BATS_TEST_TMPDIR}/required-checks"
    mkdir -p "$dir"
    local yml="${dir}/quality.yml"
    cp "$QUALITY_YML" "$yml"
    local file="${dir}/required-checks.txt"
    printf '%s\n' 'Shell Quality Checks (ubuntu-latest)' 'Shell Quality Checks (macos-latest)' >"$file"

    local expected actual
    expected="$(expected_check_names "$yml")"
    actual="$(file_check_names "$file")"
    [ "$expected" != "$actual" ] || {
        echo "the planted mismatch was not detected: expected and actual matched" >&2
        return 1
    }
    printf '%s\n' "$actual" | grep -q 'ubuntu-latest'

    # A single renamed runner is caught too, not just a wholesale change.
    printf '%s\n' 'Shell Quality Checks (ubuntu-24.04)' 'Shell Quality Checks (macos-latest)' >"$file"
    expected="$(expected_check_names "$yml")"
    actual="$(file_check_names "$file")"
    [ "$expected" != "$actual" ]
}
