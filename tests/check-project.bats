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