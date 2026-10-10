#!/usr/bin/env bash
# Test helper to get the project root directory
# This file should be sourced by test files

# `run --separate-stderr` needs 1.5.0. CI pins 1.14.0 (macOS) and 1.10.0
# (Ubuntu), both above this floor; declaring it states the real requirement
# instead of leaving tests to warn on every run.
bats_require_minimum_version 1.5.0

# Get the project root directory (parent of tests/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT

# Scripts directory
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
readonly SCRIPTS_DIR

# ---------------------------------------------------------------------------
# PATH FENCE
#
# gem, sudo and brew are faked for EVERY test in the suite, loaded from here so
# that no single .bats file can forget.
#
# Why this exists, stated plainly because it cost a real repair:
# on 2026-10-10 a test in this suite did `eval "$bypass"` in bats' own shell,
# where `gem` and `sudo` are the real binaries. The line it evaluated was
#     ALLOW_RISKY_GEM=1 gem update --sys
# which set a guard's own bypass variable and then ran a genuine system-wide
# RubyGems update. It installed 591 files into /opt/homebrew/lib/ruby/site_ruby
# and had to be repaired by hand.
#
# So: every fake RECORDS its arguments and exits 0. It performs no work of any
# kind, cannot prompt, and cannot write to /opt/homebrew or ~/.gem. A test that
# genuinely needs to assert on a fake's behaviour gives the fake a richer
# implementation and prepends its own directory, which then comes first; the
# canary in tests/safety.bats accepts that and only that.
#
# The log lives under BATS_TEST_TMPDIR, which is per test, so one test's calls
# never leak into another's assertions.
# ---------------------------------------------------------------------------

FAKE_BIN_DIR="${TMPDIR:-/tmp}/bats-fakes-$(id -u)"

if ! mkdir -p "$FAKE_BIN_DIR" 2>/dev/null; then
    printf 'test_helper: cannot create the fake bin directory %s\n' "$FAKE_BIN_DIR" >&2
    return 1 2>/dev/null || exit 1
fi

for _fence_tool in gem sudo brew; do
    # Rewritten on every load so a stale or truncated fake can never survive a
    # checkout. The redirection truncates in place, so this needs no deletion -
    # and this suite does not delete anything.
    cat >"${FAKE_BIN_DIR}/${_fence_tool}" <<'FAKE'
#!/bin/sh
# Fake gem / sudo / brew. Records the call. Does nothing. Exits 0.
printf '%s %s\n' "$(basename "$0")" "$*" >>"${BATS_TEST_TMPDIR:-/tmp}/fake-calls.log"
exit 0
FAKE
    chmod +x "${FAKE_BIN_DIR}/${_fence_tool}"
done
unset _fence_tool

export FAKE_BIN_DIR
export PATH="${FAKE_BIN_DIR}:${PATH}"

# Names the fence must resolve to. A test may add its own shim directory, and
# that is the ONLY other thing the canary accepts.
readonly FAKE_BIN_DIR

# True when a resolved path is safe to execute inside a test: the suite-wide
# fake, or a per-test shim under BATS_TEST_TMPDIR.
is_fake_path() {
    case "$1" in
    "$FAKE_BIN_DIR"/*) return 0 ;;
    "${BATS_TEST_TMPDIR:-/nonexistent}"/*) return 0 ;;
    *) return 1 ;;
    esac
}
