#!/usr/bin/env bats

load test_helper

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    export INSTALL_DIR="${BATS_TEST_TMPDIR}/install"
    mkdir -p "$HOME" "$INSTALL_DIR"
}

# Shadow `rm` with a logging no-op so a regression in validate_install_dir
# cannot delete anything, while still letting us assert that no removal
# was even attempted.
stub_rm() {
    export RM_STUB_LOG="${BATS_TEST_TMPDIR}/rm-calls.log"
    : >"$RM_STUB_LOG"

    local stub_bin="${BATS_TEST_TMPDIR}/stubbin"
    mkdir -p "$stub_bin"
    printf '#!/usr/bin/env bash\necho "rm $*" >> "%s"\nexit 0\n' \
        "$RM_STUB_LOG" >"${stub_bin}/rm"
    chmod +x "${stub_bin}/rm"

    STUB_PATH="${stub_bin}:${PATH}"
}

@test "uninstall.sh executes successfully" {
    run bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]
}

@test "uninstall.sh does not touch files outside INSTALL_DIR" {
    # Sentinel that an unisolated run would destroy by resolving
    # INSTALL_DIR from config/default.conf to $HOME/.local/bin
    local sentinel="${BATS_TEST_TMPDIR}/home/.local/bin/canary"
    mkdir -p "$(dirname "$sentinel")"
    touch "$sentinel"

    run bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]

    [ -f "$sentinel" ]
}

@test "uninstall.sh refuses INSTALL_DIR=/ and attempts no deletions" {
    stub_rm

    run env INSTALL_DIR=/ PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 78 ]
    [[ "$output" == *"INSTALL_DIR"* ]]

    # No rm was even reached, so nothing could have been deleted
    [ ! -s "$RM_STUB_LOG" ]
}

@test "uninstall.sh refuses INSTALL_DIR=// and attempts no deletions" {
    stub_rm

    # "//" is still the filesystem root; a bare `== "/"` test misses it
    run env INSTALL_DIR=// PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 78 ]
    [[ "$output" == *"refusing to continue"* ]]

    [ ! -s "$RM_STUB_LOG" ]
}

@test "uninstall.sh rejects report EX_CONFIG, not a shell error" {
    stub_rm

    run env INSTALL_DIR=/ PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"

    # die must receive "$EX_CONFIG"; a bare EX_CONFIG makes bash exit 2 with
    # "numeric argument required" on stderr (regression of the 2.1.0 fix)
    [[ "$output" != *"numeric argument required"* ]]
    [[ "$output" != *"Error (EX_CONFIG)"* ]]
}

@test "uninstall.sh refuses a top-level INSTALL_DIR" {
    stub_rm

    run env INSTALL_DIR=/usr PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 78 ]
    [[ "$output" == *"too shallow"* ]]
    [ ! -s "$RM_STUB_LOG" ]
}

@test "uninstall.sh refuses a relative INSTALL_DIR" {
    stub_rm

    run env INSTALL_DIR=relative/path PATH="$STUB_PATH" bash \
        "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 78 ]
    [[ "$output" == *"must be an absolute path"* ]]
    [ ! -s "$RM_STUB_LOG" ]
}

@test "uninstall.sh accepts a normal nested INSTALL_DIR" {
    local nested="${BATS_TEST_TMPDIR}/opt/framework/bin"
    mkdir -p "${nested}/lib"
    touch "${nested}/backup.sh"

    run env INSTALL_DIR="$nested" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"removed successfully"* ]]

    [ ! -d "${nested}/lib" ]
    [ ! -f "${nested}/backup.sh" ]
}

@test "uninstall.sh refuses INSTALL_DIR=/usr/local" {
    stub_rm

    # Two separators deep is no longer enough: rm -rf /usr/local/lib would run
    run env INSTALL_DIR=/usr/local PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 78 ]
    [[ "$output" == *"too shallow"* ]]
    [ ! -s "$RM_STUB_LOG" ]
}

@test "uninstall.sh still accepts a realistic three-level INSTALL_DIR" {
    stub_rm

    # /opt/ws/bin has 3 separators and must remain valid. Stubbed so a
    # regression cannot remove anything from the real /opt.
    run env INSTALL_DIR=/opt/ws/bin PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"too shallow"* ]]
}

@test "uninstall.sh removes the install prefix config, VERSION and marker" {
    # Realistic layout: INSTALL_DIR=<prefix>/bin, with <prefix>/config,
    # <prefix>/VERSION and <prefix>/bin/.install_dir beside the utilities.
    local prefix="${BATS_TEST_TMPDIR}/opt/ws"
    local bindir="${prefix}/bin"

    mkdir -p "${bindir}/lib" "${prefix}/config"
    printf '# cfg\n' >"${prefix}/config/default.conf"
    printf '2.1.0\n' >"${prefix}/VERSION"
    printf '%s\n' "$bindir" >"${bindir}/.install_dir"
    touch "${bindir}/backup.sh" "${bindir}/lib/logging.sh"

    run env INSTALL_DIR="$bindir" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"removed successfully"* ]]

    # utilities and lib gone (pre-existing behaviour)
    [ ! -f "${bindir}/backup.sh" ]
    [ ! -d "${bindir}/lib" ]

    # the three artifacts left behind by the old uninstall are now removed
    [ ! -f "${bindir}/.install_dir" ]
    [ ! -e "${prefix}/VERSION" ]
    [ ! -d "${prefix}/config" ]

    # the install prefix itself is NOT removed
    [ -d "$prefix" ]
}

@test "uninstall.sh leaves the install prefix alone when it is not ours" {
    stub_rm

    # A sibling config/ outside the validated prefix must be untouched.
    local bindir="${BATS_TEST_TMPDIR}/opt/other/bin"
    mkdir -p "$bindir"
    run env INSTALL_DIR="$bindir" PATH="$STUB_PATH" bash "${SCRIPTS_DIR}/uninstall.sh"
    [ "$status" -eq 0 ]

    # Nothing above the prefix was removed
    [ -d "${BATS_TEST_TMPDIR}/opt/other" ]
    [ -d "$bindir" ]
}
