#!/usr/bin/env bats

load test_helper

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    export INSTALL_DIR="${BATS_TEST_TMPDIR}/install"
    mkdir -p "$HOME" "$INSTALL_DIR"

    export FRAMEWORK_REPO="${BATS_TEST_TMPDIR}/framework"
    export UNRELATED_REPO="${BATS_TEST_TMPDIR}/unrelated"
    export BARE_ORIGIN="${BATS_TEST_TMPDIR}/origin.git"

    # Local file:// origin so fetch/pull work with no network
    git init --quiet --bare "$BARE_ORIGIN"

    # A copy of the framework, inside its own git repo, so that
    # REPO_ROOT (derived from the script's own location) is a real repo
    mkdir -p "$FRAMEWORK_REPO"
    cp -R "${SCRIPTS_DIR}" "${FRAMEWORK_REPO}/scripts"
    cp -R "${PROJECT_ROOT}/config" "${FRAMEWORK_REPO}/config"
    cp "${PROJECT_ROOT}/VERSION" "${FRAMEWORK_REPO}/VERSION"
    git init --quiet "$FRAMEWORK_REPO"
    git -C "$FRAMEWORK_REPO" symbolic-ref HEAD refs/heads/main
    git -C "$FRAMEWORK_REPO" config user.email "test@example.com"
    git -C "$FRAMEWORK_REPO" config user.name "Test"
    git -C "$FRAMEWORK_REPO" add -A
    git -C "$FRAMEWORK_REPO" commit --quiet -m "framework snapshot"
    git -C "$FRAMEWORK_REPO" remote add origin "file://${BARE_ORIGIN}"
    git -C "$FRAMEWORK_REPO" push --quiet -u origin main

    # An unrelated repo, also valid, with a distinct branch name
    mkdir -p "$UNRELATED_REPO"
    git init --quiet "$UNRELATED_REPO"
    git -C "$UNRELATED_REPO" symbolic-ref HEAD refs/heads/unrelated-work
    git -C "$UNRELATED_REPO" config user.email "test@example.com"
    git -C "$UNRELATED_REPO" config user.name "Test"
    git -C "$UNRELATED_REPO" remote add origin "file://${BARE_ORIGIN}"
    touch "${UNRELATED_REPO}/unrelated.txt"
    git -C "$UNRELATED_REPO" add -A
    git -C "$UNRELATED_REPO" commit --quiet -m "unrelated snapshot"
}

@test "sync.sh executes successfully" {
    run bash "${FRAMEWORK_REPO}/scripts/sync.sh"
    [ "$status" -eq 0 ]
}

@test "sync.sh prints completion message" {
    run bash "${FRAMEWORK_REPO}/scripts/sync.sh"
    [[ "$output" == *"Synchronization check completed."* ]]
}

@test "sync.sh acts on its own repo, not the cwd repo" {
    run bash -c "cd '${UNRELATED_REPO}' && bash '${FRAMEWORK_REPO}/scripts/sync.sh'"
    [ "$status" -eq 0 ]

    # Reports the framework repo's branch and upstream...
    [[ "$output" == *"Current branch : main"* ]]
    [[ "$output" == *"Tracking branch: origin/main"* ]]

    # ...and never the unrelated repo it was invoked from
    [[ "$output" != *"unrelated-work"* ]]
}

@test "sync.sh leaves the cwd repo unmodified" {
    local before
    before="$(git -C "$UNRELATED_REPO" rev-parse HEAD)"

    # A fetch into the wrong repo would leave a FETCH_HEAD behind
    [ ! -f "${UNRELATED_REPO}/.git/FETCH_HEAD" ]

    run bash -c "cd '${UNRELATED_REPO}' && bash '${FRAMEWORK_REPO}/scripts/sync.sh'"
    [ "$status" -eq 0 ]

    [ "$(git -C "$UNRELATED_REPO" rev-parse HEAD)" = "$before" ]
    [ -z "$(git -C "$UNRELATED_REPO" status --porcelain)" ]
    [ ! -f "${UNRELATED_REPO}/.git/FETCH_HEAD" ]
}
