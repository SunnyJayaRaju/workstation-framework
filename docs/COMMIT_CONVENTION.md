# Commit Message Convention

This project follows the **Conventional Commits** specification (https://www.conventionalcommits.org/).

---

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

---

## Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(backup): add multi-file support` |
| `fix` | Bug fix | `fix(config): handle missing BASH_SOURCE` |
| `docs` | Documentation only | `docs: update coding standards` |
| `style` | Formatting, no logic change | `style: shfmt formatting` |
| `refactor` | Code restructuring | `refactor: extract prelude.sh` |
| `perf` | Performance improvement | `perf: lazy load libraries` |
| `test` | Test changes | `test: add idempotency tests` |
| `build` | Build system/CI | `build: add macOS runner` |
| `ci` | CI configuration | `ci: update shellcheck version` |
| `chore` | Maintenance | `chore: update dependencies` |
| `revert` | Revert previous commit | `revert: feat(backup): add multi-file` |

---

## Scope (Optional)

Scope identifies the affected component:

- `backup`, `restore`, `install`, `uninstall`, `update`
- `doctor`, `sync`, `clean`, `bootstrap`
- `config`, `logging`, `errors`, `filesystem`, `checks`, `colors`
- `secrets`, `prelude`
- `test`, `ci`, `docs`, `build`
- `release`

---

## Description

- **Imperative mood**: "add" not "added" or "adds"
- **Lowercase first letter**
- **No period at end**
- **Max 72 characters** (50 ideal)
- **Reference issue** if applicable: `fix(backup): handle missing file (#123)`

---

## Body (Optional)

- Explain **what** and **why**, not **how**
- Wrap at 72 characters
- Use bullet points for multiple items

```
fix(config): handle missing BASH_SOURCE in sourced context

When config.sh is sourced from command line (not a file),
BASH_SOURCE[0] is unset. This caused "parameter not set" error.

- Use ${BASH_SOURCE[0]:-${0}} fallback
- Unset temporary variable after use
```

---

## Footer (Optional)

- **Breaking changes**: `BREAKING CHANGE: <description>`
- **Issue references**: `Closes #123`, `Fixes #456`, `Relates to #789`
- **Co-authors**: `Co-authored-by: Name <email>`

---

## Examples

### Feature
```
feat(backup): add configurable backup sources

Allow BACKUP_SOURCES env var to specify multiple files.
Default: .zshrc .gitconfig .ssh/config

Closes #42
```

### Bug Fix
```
fix(config): prevent parameter not set error on BASH_SOURCE

When sourced from command line, BASH_SOURCE[0] is empty.
Use ${0} fallback and handle gracefully.
```

### Documentation
```
docs: add commit message convention guide

Document Conventional Commits format for contributors.
```

### Refactor
```
refactor(lib): add prelude.sh for single library import

Reduces boilerplate in scripts from 6 source lines to 1.
```

### Test
```
test(backup): add idempotency and multi-file tests

Verify backup.sh creates separate timestamped files on repeated runs.
```

### CI
```
ci: add macOS runner to quality workflow

Ensure framework tests run on target platform (macOS).
```

---

## Automation

- **commitlint** runs in CI to enforce format
- **semantic-release** (future) will auto-version from commit types:
  - `feat` → MINOR
  - `fix` → PATCH
  - `BREAKING CHANGE` → MAJOR

---

## Quick Reference

```bash
# Good
feat(install): add --dry-run flag
fix(shell-quality): use consistent shfmt flags
docs: update README badges
refactor: extract config parser to lib/config.sh
test: add integration test for install→uninstall cycle
chore: update shellcheck to v0.10.0

# Bad
Fixed bug
Update readme
WIP
feat: add thing (no scope)
FIX: crash (uppercase type)
```