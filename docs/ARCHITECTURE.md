# Architecture

> High-level architectural overview of the Developer Workstation Framework.

---

# Purpose

The purpose of this repository is to manage a macOS development workstation using engineering practices instead of ad-hoc scripts.

Every configuration, script, template, and document is treated as version-controlled infrastructure.

This repository is intended to evolve over time while remaining maintainable, reproducible, and well documented.

---

# Design Principles

The repository follows these principles:

- Documentation first
- Modular design
- Reusable components
- Version-controlled changes
- Incremental improvements
- Quality before automation
- Simplicity over unnecessary complexity

---

# Repository Structure

```text
Workstation-Framework/
│
├── .vscode/
│   Workspace settings
│
├── docs/
│   Project documentation
│
├── scripts/
│   Production-ready utility scripts
│
├── templates/
│   Reusable script templates
│
├── README.md
│
└── .editorconfig
```

---

# Component Responsibilities

## README.md

Acts as the project entry point.

Provides:

- overview
- goals
- features
- quick navigation

---

## docs/

Contains long-form documentation.

Examples include:

- architecture
- coding standards
- roadmap
- review checklist
- changelog

---

## templates/

Contains reusable templates that define the standard structure of new shell scripts.

Every production script should begin life from one of these templates.

---

## scripts/

Contains stable, tested utilities.

Examples:

- backup.sh
- check-project.sh
- doctor.sh
- install.sh
- repo-clean.sh
- restore.sh
- shell-quality.sh
- sync.sh
- uninstall.sh
- update.sh

---



# Documentation Strategy

Documentation follows a Docs-as-Code approach.

This means:

- Markdown
- Git version control
- Peer review
- Incremental improvements

Documentation evolves together with the codebase rather than existing as a separate artifact.

---

# Quality Pipeline

Every utility script follows the same lifecycle.

```text
Idea
    ↓
Design
    ↓
Implementation
    ↓
Formatting
    ↓
Static Analysis
    ↓
Testing
    ↓
Documentation
    ↓
Git Review
    ↓
Production
```

---

# Future Growth

Planned additions include:

- automated testing
- GitHub Actions
- additional shell utilities
- reusable templates
- documentation automation
- workstation bootstrap scripts

---

# Architecture Ownership

This document is a living document.

Whenever the repository structure or engineering practices change, this file should be updated in the same change set.

---

# Public Library API: secrets.sh

## Purpose

`scripts/lib/secrets.sh` provides a portable secrets management interface for macOS. It abstracts secret storage and retrieval across multiple backends:

- **1Password CLI** (op) — team/shared secrets
- **macOS Keychain** (security) — local per-user secrets
- **Environment variables** — CI/CD and fallback

## Backend Priority

1. 1Password (if signed in)
2. macOS Keychain
3. Environment variables (uppercase with underscores)

## API

```bash
source scripts/lib/secrets.sh

# Get a secret (tries all backends in order)
secret=$(get_secret "github-token")

# Store a secret (uses Keychain)
store_secret "api-key" "my-secret-value"

# Delete a secret
delete_secret "old-token"

# List all stored secrets
list_secrets
```

## Direct Backend Access

```bash
# 1Password (requires op CLI and sign-in)
get_secret_op "Item Name" "field" ["vault"]
store_secret_op "Item Name" "field" "value" ["vault"]

# macOS Keychain
get_secret_keychain "service" "account"
store_secret_keychain "service" "account" "value"
```

## Security Notes

- No command substitution or eval — safe for untrusted input
- Keychain entries use service name `workstation-framework`
- 1Password requires `op` CLI and active session
- Environment variable fallback uses uppercase with underscores (e.g., `github-token` → `GITHUB_TOKEN`)

## Testing

See `tests/secrets.bats` for contract tests that exercise the public API against a real Keychain (mocked in CI).
