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
    for utility in backup check-project repo-clean doctor install \
        restore shell-quality sync uninstall update; do
        run bash "${SCRIPTS_DIR}/shell-quality.sh" "${SCRIPTS_DIR}/${utility}.sh"
        [ "$status" -eq 0 ]
        [[ "$output" != *"SC1091"* ]]
    done
}