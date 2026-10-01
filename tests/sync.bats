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

# --- FIX 5: real local-remote fetch path (M18) -------------------------

# A self-contained copy of the framework repo so sync.sh's REPO_ROOT
# (SCRIPT_DIR/..) is a throwaway git repo, never the real one.
make_sync_repo() {
    SYNC_REPO="${BATS_TEST_TMPDIR}/syncrepo-$1"
    mkdir -p "$SYNC_REPO"
    cp -R "${SCRIPTS_DIR}" "${SYNC_REPO}/scripts"
    git init --quiet "$SYNC_REPO"
    git -C "$SYNC_REPO" symbolic-ref HEAD refs/heads/main
    git -C "$SYNC_REPO" config user.email "t@example.com"
    git -C "$SYNC_REPO" config user.name "T"
    git -C "$SYNC_REPO" add -A
    git -C "$SYNC_REPO" commit --quiet -m snapshot
    printf '%s' "$SYNC_REPO"
}

@test "sync.sh fetches new upstream commits into its remote-tracking ref" {
    local repo origin other
    repo="$(make_sync_repo real-fetch)"
    origin="${BATS_TEST_TMPDIR}/fetch-origin.git"
    git init --quiet --bare "$origin"

    git -C "$repo" remote add origin "$origin"
    git -C "$repo" push --quiet -u origin main

    # a second clone pushes a NEW commit to the same bare origin
    other="${BATS_TEST_TMPDIR}/other-clone"
    git clone --quiet "$origin" "$other"
    git -C "$other" config user.email "t@example.com"
    git -C "$other" config user.name "T"
    echo "upstream work" >"${other}/upstream.txt"
    git -C "$other" add -A
    git -C "$other" commit --quiet -m "upstream commit"
    git -C "$other" push --quiet origin main
    local new_sha
    new_sha="$(git -C "$other" rev-parse HEAD)"

    # before sync, our remote-tracking ref is still the old commit
    [ "$(git -C "$repo" rev-parse origin/main)" != "$new_sha" ]

    run bash "${repo}/scripts/sync.sh"
    [ "$status" -eq 0 ]

    # the fetch must have pulled the new commit across
    [ "$(git -C "$repo" rev-parse origin/main)" = "$new_sha" ]
}

# --- FIX 2 (L1): retry around the network call -------------------------

@test "sync.sh retries a transient fetch failure and then succeeds" {
    local repo stub counter
    repo="$(make_sync_repo retry)"
    git init --quiet --bare "${BATS_TEST_TMPDIR}/retry-origin.git"
    git -C "$repo" remote add origin "${BATS_TEST_TMPDIR}/retry-origin.git"
    git -C "$repo" push --quiet -u origin main

    counter="${BATS_TEST_TMPDIR}/fetch-calls"
    : >"$counter"
    stub="${BATS_TEST_TMPDIR}/stubbin-retry"
    mkdir -p "$stub"
    cat >"${stub}/git" <<STUB
#!/usr/bin/env bash
for a in "\$@"; do
    if [ "\$a" = "fetch" ]; then
        echo call >> "$counter"
        n=\$(wc -l < "$counter" | tr -d ' ')
        # fail the first two fetch attempts, then behave like real git
        if [ "\$n" -lt 3 ]; then
            echo "transient network error" >&2
            exit 128
        fi
        break
    fi
done
exec $(command -v git) "\$@"
STUB
    chmod +x "${stub}/git"

    PATH="${stub}:${PATH}" run bash "${repo}/scripts/sync.sh"

    [ "$status" -eq 0 ]
    # it must have tried three times, not given up on the first
    [ "$(wc -l <"$counter" | tr -d ' ')" = "3" ]
}

@test "sync.sh gives up cleanly when every fetch attempt fails" {
    local repo stub counter
    repo="$(make_sync_repo retry-exhausted)"
    git init --quiet --bare "${BATS_TEST_TMPDIR}/dead-origin.git"
    git -C "$repo" remote add origin "${BATS_TEST_TMPDIR}/dead-origin.git"
    git -C "$repo" push --quiet -u origin main

    counter="${BATS_TEST_TMPDIR}/dead-calls"
    : >"$counter"
    stub="${BATS_TEST_TMPDIR}/stubbin-dead"
    mkdir -p "$stub"
    cat >"${stub}/git" <<STUB
#!/usr/bin/env bash
for a in "\$@"; do
    if [ "\$a" = "fetch" ]; then
        echo call >> "$counter"
        echo "network down" >&2
        exit 128
    fi
done
exec $(command -v git) "\$@"
STUB
    chmod +x "${stub}/git"

    PATH="${stub}:${PATH}" run bash "${repo}/scripts/sync.sh"

    [ "$status" -ne 0 ]
    # bounded: it must stop trying, not loop forever
    [ "$(wc -l <"$counter" | tr -d ' ')" = "3" ]
}
