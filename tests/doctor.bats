#!/usr/bin/env bats

load test_helper

@test "doctor.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/doctor.sh"

    [ "$status" -eq 0 ]
}

@test "doctor.sh prints completion message" {
    run bash "${SCRIPTS_DIR}/doctor.sh"

    [[ "$output" == *"Doctor completed."* ]]
}
# --- FIX 3 (L14): tool coverage and version staleness ------------------

@test "doctor.sh checks for bats as a required tool" {
    run bash "${SCRIPTS_DIR}/doctor.sh"

    [[ "$output" == *"bats"* ]]
    # still checks the others it always did
    [[ "$output" == *"shellcheck"* ]]
    [[ "$output" == *"shfmt"* ]]
    [[ "$output" == *"jq"* ]]
}

@test "doctor.sh reports the version it is checking" {
    run bash "${SCRIPTS_DIR}/doctor.sh"

    [[ "$output" == *"$(cat "${PROJECT_ROOT}/VERSION")"* ]]
}

@test "doctor.sh compares the installed VERSION with the source VERSION" {
    # doctor.sh must run from the SOURCE tree for this to mean anything:
    # from an install, SCRIPT_DIR/../VERSION is the installed version itself.
    local staging="${BATS_TEST_TMPDIR}/stage"
    mkdir -p "${staging}/install"
    # an installed copy a whole version behind: the live-machine staleness
    # that used to be invisible to doctor.sh
    echo "0.0.1" >"${staging}/VERSION"

    run env HOME="${BATS_TEST_TMPDIR}/home" INSTALL_DIR="${staging}/install" \
        bash "${SCRIPTS_DIR}/doctor.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"installed 0.0.1"* ]]
    [[ "$output" == *"source $(cat "${PROJECT_ROOT}/VERSION")"* ]]
    [[ "$output" == *"update.sh"* ]]
}

@test "doctor.sh passes the version check when installed and source agree" {
    local staging="${BATS_TEST_TMPDIR}/stage-ok"
    mkdir -p "${staging}/install"
    cp "${PROJECT_ROOT}/VERSION" "${staging}/VERSION"

    run env HOME="${BATS_TEST_TMPDIR}/home" INSTALL_DIR="${staging}/install" \
        bash "${SCRIPTS_DIR}/doctor.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"installed VERSION matches source"* ]]
}
