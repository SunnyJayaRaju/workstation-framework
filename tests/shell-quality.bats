#!/usr/bin/env bats

load test_helper

@test "shell-quality.sh requires an argument" {
    run bash "${SCRIPTS_DIR}/shell-quality.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shell-quality.sh works with a valid script" {
    run bash "${SCRIPTS_DIR}/shell-quality.sh" "${SCRIPTS_DIR}/lib/errors.sh"

    [ "$status" -eq 0 ]
}

@test "shell-quality.sh passes a utility that sources lib files" {
    # All 10 utilities source lib/*.sh. shellcheck must not report SC1091
    # ("Not following") for them, or the tool fails on the whole framework.
    run bash "${SCRIPTS_DIR}/shell-quality.sh" "${SCRIPTS_DIR}/backup.sh"

    [ "$status" -eq 0 ]
    [[ "$output" != *"SC1091"* ]]
    [[ "$output" == *"All quality checks passed"* ]]
}

@test "shell-quality.sh passes every framework utility" {
    local utility
    for utility in backup check-project repo-clean doctor install mac-routine \
        restore shell-quality sync uninstall update; do
        run bash "${SCRIPTS_DIR}/shell-quality.sh" "${SCRIPTS_DIR}/${utility}.sh"
        [ "$status" -eq 0 ]
        [[ "$output" != *"SC1091"* ]]
    done
}

@test "the utility list here matches the one install.sh installs" {
    # This list is hard-coded, so it silently goes stale: a new utility ships
    # unlinted by this test the moment it is added. install.sh is the authority.
    run bash "${SCRIPTS_DIR}/check-project.sh"

    [ "$status" -eq 0 ]
    run grep -oE '^    [a-z-]+\.sh$' "${SCRIPTS_DIR}/install.sh"
    local installed
    installed="$(printf '%s\n' "$output" | sort -u)"
    [[ "$installed" == *"mac-routine.sh"* ]]
    [[ "$installed" == *"backup.sh"* ]]
}
# --- FIX 1: a missing tool is an environment problem, not a lint finding --

# A PATH with only what shell-quality.sh itself needs, so shellcheck/shfmt
# are genuinely absent.
minimal_path() {
    local dir="${BATS_TEST_TMPDIR}/minpath"
    mkdir -p "$dir"
    local c
    for c in bash env dirname basename date command cat printf sed grep head; do
        ln -sf "$(command -v "$c")" "${dir}/$c"
    done
    echo "$dir"
}

@test "shell-quality.sh reports a missing shellcheck as an environment problem" {
    local safe
    safe="$(minimal_path)"

    run env PATH="$safe" bash "${SCRIPTS_DIR}/shell-quality.sh" \
        "${SCRIPTS_DIR}/lib/errors.sh"

    # non-zero: the environment is incomplete
    [ "$status" -ne 0 ]

    # clearly a missing-tool message, NOT a lint verdict
    [[ "$output" == *"shellcheck"* ]]
    [[ "$output" == *"not installed"* ]]
    [[ "$output" != *"ShellCheck found issues"* ]]
    [[ "$output" != *"Quality checks failed"* ]]
}

@test "shell-quality.sh reports a missing shfmt as an environment problem" {
    local safe
    safe="$(minimal_path)"

    run env PATH="$safe" bash "${SCRIPTS_DIR}/shell-quality.sh" \
        "${SCRIPTS_DIR}/lib/errors.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"shfmt"* ]]
    [[ "$output" == *"not installed"* ]]
    [[ "$output" != *"Formatting issues found"* ]]
}
