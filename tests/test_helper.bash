#!/usr/bin/env bash
# Test helper to get the project root directory
# This file should be sourced by test files

# Get the project root directory (parent of tests/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT

# Scripts directory
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
readonly SCRIPTS_DIR
