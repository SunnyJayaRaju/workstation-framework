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
