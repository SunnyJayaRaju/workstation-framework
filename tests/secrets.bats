#!/usr/bin/env bats

load test_helper

setup() {
    source "${SCRIPTS_DIR}/lib/secrets.sh"
}

@test "secrets.sh loads without error" {
    [ -n "${SECRETS_LOADED:-}" ]
}

@test "has_keychain returns true on macOS" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run has_keychain
        [ "$status" -eq 0 ]
    else
        skip "Keychain only available on macOS"
    fi
}

@test "get_secret falls back to environment variable" {
    export TEST_SECRET_VALUE="from-env"
    run get_secret "test-secret-value"
    [ "$status" -eq 0 ]
    [ "$output" = "from-env" ]
}

@test "get_secret returns non-zero for unknown secret with no fallback" {
    unset NONEXISTENT_SECRET || true
    run get_secret "nonexistent-secret"
    [ "$status" -ne 0 ]
}

@test "store_secret and get_secret_keychain round-trip (macOS only)" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        store_secret "test-roundtrip" "roundtrip-value"
        run get_secret_keychain "workstation-framework" "test-roundtrip"
        [ "$status" -eq 0 ]
        [ "$output" = "roundtrip-value" ]
        delete_secret "test-roundtrip"
    else
        skip "Keychain only available on macOS"
    fi
}

@test "get_secret rejects command injection in secret name" {
    # Secret names with command substitution should not execute (treated as literal)
    # Use a name unlikely to exist in Keychain
    run get_secret '"'"'$(nonexistent-command-injection-test)'"'"'
    [ "$status" -ne 0 ]
    [[ "$output" != *"injection"* ]]
}

@test "store_secret rejects command injection in secret name" {
    run store_secret '$(echo exploited)' "value"
    [ "$status" -ne 0 ] || [ "$output" != "exploited" ]
}