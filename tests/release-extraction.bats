#!/usr/bin/env bats

# The release workflow builds a published release body by extracting one
# version's section out of docs/CHANGELOG.md with an inline awk program.
# That awk once emitted the separator and the *next* version's heading at the
# end of every published body, because awk runs rules in order and the
# `p {print}` rule preceded the boundary check. This test runs the awk
# straight out of the workflow file, so the script that CI uses is the script
# under test.

load test_helper

# Pull the awk program out of release.yml, exactly as the workflow writes it.
release_awk() {
    local raw="${BATS_TEST_TMPDIR}/extract.awk"
    awk '/cat > \/tmp\/extract_changelog\.awk/ {found=1; next}
         found && /AWK_EOF/ {exit}
         found {sub(/^ +/, ""); print}' \
        "${PROJECT_ROOT}/.github/workflows/release.yml" >"$raw"
    printf '%s' "$raw"
}

extract_for() {
    awk -v ver="$1" -f "$(release_awk)" "${PROJECT_ROOT}/docs/CHANGELOG.md"
}

@test "the release awk program is found in the workflow" {
    run bash -c 'grep -q "AWK_EOF" "$1"' _ "${PROJECT_ROOT}/.github/workflows/release.yml"
    [ "$status" -eq 0 ]

    # a non-empty program, not just the heredoc markers
    [ -n "$(release_awk)" ]
}

@test "extraction for 2.2.0 starts at the 2.2.0 heading" {
    run bash -c 'true'
    local out="$(extract_for 2.2.0)"

    [ -n "$out" ]
    [[ "${out%%$'\n'*}" == "## [2.2.0]"* ]]
}

@test "extraction does not leak the next version's heading" {
    local out
    out="$(extract_for 2.2.0)"

    # zero headings for any other version
    run bash -c 'grep -c "^## \[" <<<"$1" | tr -d " "' _ "$out"
    [ "$output" = "1" ]

    [[ "$out" != *"## [2.1.0]"* ]]
}

@test "extraction does not end with a stray separator" {
    local out last
    out="$(extract_for 2.2.0)"
    # the body must not end with "---" or with blank padding after it
    while [[ "${out}" == *$'\n' ]]; do out="${out%$'\n'}"; done

    [[ "$out" != *"---" ]]
}

@test "extraction keeps the whole 2.2.0 entry, not just its start" {
    local out
    out="$(extract_for 2.2.0)"

    # the final bullet of the 2.2.0 section is present, so nothing was
    # truncated at the boundary
    [[ "$out" == *"several releases behind unnoticed."* ]]
    # and the section is substantial
    [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -gt 50 ]
}
