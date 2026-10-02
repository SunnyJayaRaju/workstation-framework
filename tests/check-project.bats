#!/usr/bin/env bats

load test_helper

@test "check-project.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/check-project.sh"

    [ "$status" -eq 0 ]
}

@test "check-project.sh prints success message" {
    run bash "${SCRIPTS_DIR}/check-project.sh"

    [[ "$output" == *"Repository structure verified."* ]]
}

@test "check-project.sh exits non-zero when .git is missing" {
    # Create a temp directory without .git
    local temp_dir
    temp_dir="$(mktemp -d)"
    # Copy check-project.sh and its dependencies to temp dir
    cp -r "${SCRIPTS_DIR}"/* "$temp_dir/"
    # Remove .git if it exists (it won't in temp dir)
    
    # Run from temp dir (no .git)
    run bash "$temp_dir/check-project.sh"
    
    [ "$status" -ne 0 ]
    [[ "$output" == *"FAIL] Git repository"* ]]
    
    rm -rf "$temp_dir"
}
# --- FIX 1: CI tool versions are pinned, and the docs say so -------------

@test "quality.yml pins exact shellcheck, shfmt and bats versions" {
    local workflow="${PROJECT_ROOT}/.github/workflows/quality.yml"

    # Ubuntu side: exact apt versions
    run grep -q 'shellcheck=0\.9\.0-1' "$workflow"
    [ "$status" -eq 0 ]
    run grep -q 'shfmt=3\.8\.0-1' "$workflow"
    [ "$status" -eq 0 ]
    run grep -q 'bats=1\.10\.0-1' "$workflow"
    [ "$status" -eq 0 ]

    # No bare, unpinned installs may remain
    run grep -qE 'apt-get install -y (shellcheck|shfmt|bats)( |$)' "$workflow"
    [ "$status" -ne 0 ]
}

@test "SHELL_CODING_STANDARDS.md states the actual pinned versions" {
    local standards="${PROJECT_ROOT}/docs/SHELL_CODING_STANDARDS.md"

    run grep -q '0\.9\.0-1' "$standards"
    [ "$status" -eq 0 ]
    run grep -q '3\.8\.0-1' "$standards"
    [ "$status" -eq 0 ]
    run grep -q '1\.10\.0-1' "$standards"
    [ "$status" -eq 0 ]

    # the old unproven claim must be gone
    run grep -q 'Latest stable' "$standards"
    [ "$status" -ne 0 ]
}

# --- FIX 3: the broken, unused prelude.sh is removed ----------------------

@test "the broken prelude.sh library has been removed" {
    [ ! -f "${SCRIPTS_DIR}/lib/prelude.sh" ]
}

@test "no documentation presents prelude.sh as available" {
    run grep -rn 'prelude' \
        "${PROJECT_ROOT}/docs/ARCHITECTURE.md" "${PROJECT_ROOT}/README.md"
    [ "$status" -ne 0 ]
}

# --- FIX 2 (L1): `make all` must run a bash -n syntax gate first ---------

@test "the Makefile has a syntax target that runs bash -n" {
    # -A2 so the tab-indented recipe line is included, not just the target
    run grep -A2 -E '^syntax:' "${PROJECT_ROOT}/Makefile"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bash -n"* ]]
}

@test "the all target depends on syntax and lists it first" {
    local all_line
    all_line="$(grep -E '^all:' "${PROJECT_ROOT}/Makefile")"

    [[ "$all_line" == *"syntax"* ]]

    # first prerequisite is syntax, matching the documented gate order
    local first
    first="$(printf '%s\n' "$all_line" | awk '{print $2}')"
    [ "$first" = "syntax" ]
}

@test "the syntax gate fails on a broken script" {
    local proj="${BATS_TEST_TMPDIR}/mkproj"
    mkdir -p "${proj}/scripts" "${proj}/templates"
    cp "${PROJECT_ROOT}/Makefile" "${proj}/Makefile"

    # one good script, one with an unterminated `if`
    printf '#!/usr/bin/env bash\necho ok\n' >"${proj}/scripts/ok.sh"
    printf '#!/usr/bin/env bash\nif true; then echo unterminated\n' \
        >"${proj}/scripts/broken.sh"

    run make -C "$proj" syntax
    [ "$status" -ne 0 ]
}

@test "the syntax gate passes on a clean tree" {
    run make syntax
    [ "$status" -eq 0 ]
}

# --- FIX 1 (L4): no eval-based assert helper ---------------------------

@test "errors.sh contains no eval and no assert helper" {
    run grep -c 'eval' "${SCRIPTS_DIR}/lib/errors.sh"
    [ "$output" = "0" ]

    run grep -c 'assert()' "${SCRIPTS_DIR}/lib/errors.sh"
    [ "$output" = "0" ]
}

# --- FIX 2 (L3/L4): mandated helpers are actually used -----------------

@test "sync.sh wraps its network call in retry" {
    run grep -q 'retry' "${SCRIPTS_DIR}/sync.sh"
    [ "$status" -eq 0 ]
}

@test "command-availability checks use the shared helpers, not raw command -v" {
    # Where aborting is correct, the terminating helper is used.
    run grep -q 'require_command git' "${SCRIPTS_DIR}/sync.sh"
    [ "$status" -eq 0 ]

    # Where the script must warn and continue, the predicate is used instead --
    # require_command here would turn a missing linter into a failed run.
    run grep -q 'check_command_exists' "${SCRIPTS_DIR}/shell-quality.sh"
    [ "$status" -eq 0 ]

    run grep -q 'check_command_exists' "${SCRIPTS_DIR}/lib/secrets.sh"
    [ "$status" -eq 0 ]

    # and none of them hand-roll it any more
    # a single total across both files; grep -c prints per-file counts
    run bash -c "cat '${SCRIPTS_DIR}/shell-quality.sh' '${SCRIPTS_DIR}/lib/secrets.sh' \
        | grep -c 'command -v' || true"
    [ "$output" = "0" ]
}

# --- FIX 4 (L10): sync.sh is honest about pruning and network failure ---

@test "sync.sh documents that it prunes remote-tracking refs" {
    run bash "${SCRIPTS_DIR}/sync.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--prune"* ]]
}

@test "sync.sh reports a clear message when the remote is unreachable" {
    local framework_repo="${BATS_TEST_TMPDIR}/sync-offline"
    mkdir -p "$framework_repo"
    cp -R "${SCRIPTS_DIR}" "${framework_repo}/scripts"
    cp -R "${PROJECT_ROOT}/config" "${framework_repo}/config"
    git init --quiet "$framework_repo"
    git -C "$framework_repo" symbolic-ref HEAD refs/heads/main
    git -C "$framework_repo" config user.email "t@example.com"
    git -C "$framework_repo" config user.name "T"
    git -C "$framework_repo" add -A
    git -C "$framework_repo" commit --quiet -m snapshot
    # an origin that cannot be reached
    git -C "$framework_repo" remote add origin "file:///nonexistent/definitely-not-here.git"

    run bash "${framework_repo}/scripts/sync.sh"

    [ "$status" -ne 0 ]
    # must name the failure in our own words, not just leak git's stderr
    [[ "$output" == *"could not reach"* ]]
    [[ "$output" == *"origin"* ]]
}

# --- FIX 3 (L6/L7): explicit pass/fail and wider coverage --------------

# A throwaway project that looks like the real one, minus one thing.
make_project_missing() {
    local missing="$1"
    PROJ="${BATS_TEST_TMPDIR}/proj-missing-${missing//\//_}"
    mkdir -p "${PROJ}/.git" "${PROJ}/.vscode" "${PROJ}/docs" \
        "${PROJ}/scripts" "${PROJ}/scripts/lib" "${PROJ}/templates" \
        "${PROJ}/tests" "${PROJ}/assets" "${PROJ}/config"
    cp -R "${SCRIPTS_DIR}/." "${PROJ}/scripts/"
    cp "${PROJECT_ROOT}/README.md" "${PROJ}/README.md"
    cp "${PROJECT_ROOT}/.gitignore" "${PROJ}/.gitignore"
    cp "${PROJECT_ROOT}/.editorconfig" "${PROJ}/.editorconfig"
    cp "${PROJECT_ROOT}/VERSION" "${PROJ}/VERSION"
    cp "${PROJECT_ROOT}/Makefile" "${PROJ}/Makefile"
    cp "${PROJECT_ROOT}/config/default.conf" "${PROJ}/config/default.conf"
    rm -rf "${PROJ}/${missing}"
}

@test "check-project.sh reports a specific failure for a missing VERSION" {
    make_project_missing "VERSION"

    run bash "${PROJ}/scripts/check-project.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"VERSION"* ]]
    [[ "$output" != *"Repository structure verified."* ]]
}

@test "check-project.sh reports a specific failure for a missing Makefile" {
    make_project_missing "Makefile"

    run bash "${PROJ}/scripts/check-project.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Makefile"* ]]
    [[ "$output" != *"Repository structure verified."* ]]
}

@test "check-project.sh reports a specific failure for a missing config" {
    make_project_missing "config"

    run bash "${PROJ}/scripts/check-project.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"config"* ]]
    [[ "$output" != *"Repository structure verified."* ]]
}

@test "check-project.sh succeeds explicitly on a complete project" {
    make_project_missing "nothing-missing"

    run bash "${PROJ}/scripts/check-project.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository structure verified."* ]]
}

@test "check-project.sh checks VERSION, config, Makefile and the utilities" {
    run grep -q 'VERSION' "${SCRIPTS_DIR}/check-project.sh"
    [ "$status" -eq 0 ]
    run grep -q 'Makefile' "${SCRIPTS_DIR}/check-project.sh"
    [ "$status" -eq 0 ]
    run grep -q 'config' "${SCRIPTS_DIR}/check-project.sh"
    [ "$status" -eq 0 ]
}

# --- FIX (addendum): each utility script checked by name ----------------
# `scripts/` existing says nothing about the utilities inside it. Deleting
# backup.sh used to leave the directory check green, so a missing utility
# surfaced only when something tried to run it.

@test "check-project.sh checks each of the 10 utility scripts by name" {
    for s in backup.sh restore.sh install.sh uninstall.sh update.sh \
        sync.sh repo-clean.sh shell-quality.sh doctor.sh check-project.sh; do
        run grep -q "record_path \"scripts/${s}\"" "${SCRIPTS_DIR}/check-project.sh"
        [ "$status" -eq 0 ]
    done
}

@test "check-project.sh names a missing utility script specifically" {
    make_project_missing "nothing-missing"
    rm -f "${PROJ}/scripts/backup.sh"

    run bash "${PROJ}/scripts/check-project.sh"

    [ "$status" -ne 0 ]
    # named individually, not just "the scripts directory"
    [[ "$output" == *"backup.sh"* ]]
    [[ "$output" != *"Repository structure verified."* ]]
}

@test "check-project.sh still passes when every utility script is present" {
    make_project_missing "nothing-missing"

    run bash "${PROJ}/scripts/check-project.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository structure verified."* ]]
}
