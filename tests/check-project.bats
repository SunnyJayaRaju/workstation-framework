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
