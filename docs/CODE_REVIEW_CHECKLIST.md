# Code Review Checklist

Use this checklist for every Pull Request. All items must pass before merge.

---

## Documentation

- [ ] **README.md** updated if user-facing behavior changed
- [ ] **CHANGELOG.md** updated with version, date, and categorized changes
- [ ] **Code comments** explain *why*, not *what* (for non-obvious logic)
- [ ] **Function headers** present for new public functions (args, returns, side effects)
- [ ] **Architecture docs** updated if structure changed (`docs/ARCHITECTURE.md`)
- [ ] **Inline examples** in usage/help text are accurate

---

## Style

- [ ] **File header** matches standard (name, version, purpose)
- [ ] **`set -euo pipefail`** at top of every new/modified script
- [ ] **Naming conventions** followed (see `SHELL_CODING_STANDARDS.md`)
- [ ] **4-space indentation**, no tabs
- [ ] **Line length** ≤ 100 chars (soft), ≤ 120 chars (hard)
- [ ] **Consistent brace style** (`if [[ ... ]]; then` on same line)
- [ ] **Quoted variable expansions** — `"$VAR"` everywhere
- [ ] **Local variables declared** at function top
- [ ] **No global state mutation** without justification
- [ ] **Constants are `readonly`** with `UPPER_SNAKE_CASE`

---

## Syntax

- [ ] **`bash -n`** passes on all modified scripts
- [ ] **No syntax errors** in heredocs, arrays, conditionals
- [ ] **Proper array iteration** — `"${ARRAY[@]}"` not `$ARRAY`
- [ ] **Command substitution** uses `$(...)` not backticks
- [ ] **Arithmetic** uses `(( ... ))` not `expr`
- [ ] **String comparison** uses `[[ ]]` not `[ ]`
- [ ] **Glob patterns** in `[[ ]]` unquoted on right side

---

## Static Analysis

- [ ] **`shellcheck`** passes with zero warnings/errors
- [ ] **`shfmt -d -i 4 -ci`** shows no diffs (or run `make format`)
- [ ] **No `SC1091` suppressions** without comment explaining why
- [ ] **No `SC2034` unused variables** — remove or prefix with `_`
- [ ] **No `SC2155` declare/assign separation** — split if needed
- [ ] **No `SC2254` case pattern quoting** — quote patterns

---

## Runtime Testing

- [ ] **`make test`** passes (all 35+ tests green)
- [ ] **New scripts have test file** (`tests/<name>.bats`)
- [ ] **Test coverage** includes:
  - [ ] Happy path (success)
  - [ ] Error paths (invalid args, missing files, missing deps)
  - [ ] Idempotency (run twice = same result)
  - [ ] Edge cases (empty input, special chars, permissions)
- [ ] **Integration tests** pass (`tests/integration.bats`)
- [ ] **Tests use `setup`/`teardown`** for isolation
- [ ] **Tests use `BATS_TEST_TMPDIR`** for temp files
- [ ] **No flaky tests** — no timing-dependent assertions

---

## Error Handling

- [ ] **Sources `errors.sh`** for standardized exit codes
- [ ] **Uses `die` for fatal errors** — never bare `exit 1`
- [ ] **Validates required commands** with `require_command`
- [ ] **Validates required files** with `require_file`
- [ ] **Validates required variables** with `require_var`
- [ ] **Validates required directories** with `require_directory`
- [ ] **Handles transient failures** with `retry` for network ops
- [ ] **Exit codes match `errors.sh` constants** (no magic numbers)
- [ ] **Error messages are actionable** — tell user what to fix

---

## Security

- [ ] **No `eval` on untrusted input** — config parser validates KEY=VALUE only
- [ ] **No arbitrary `source`** — config files parsed, not sourced
- [ ] **No command injection** — user input never in command position
- [ ] **Path traversal prevented** — paths validated/normalized
- [ ] **Temp files** use `mktemp` or `BATS_TEST_TMPDIR`
- [ ] **Permissions** — scripts `chmod +x` only when installing
- [ ] **Secrets** — never logged, use `secrets.sh` for Keychain/1Password
- [ ] **No hardcoded credentials** — use environment or secrets library

---

## Performance

- [ ] **No unnecessary subshells** — prefer builtins
- [ ] **Loop over arrays** not command output
- [ ] **`grep -q`** not `grep | wc -l` for existence checks
- [ ] **`mapfile`** for reading lines into arrays
- [ ] **Lazy evaluation** — short-circuit `&&`/`||` in conditionals

---

## Compatibility

- [ ] **macOS compatible** (primary target)
- [ ] **Bash 3.2+ compatible** (macOS default) — no `mapfile` without fallback
- [ ] **POSIX-compliant where possible** — avoid Bash 4+ features
- [ ] **No GNU-only flags** unless macOS alternative documented

---

## CI/CD

- [ ] **GitHub Actions** pass on `ubuntu-latest` and `macos-latest`
- [ ] **All quality gates** in `make all` pass
- [ ] **Dependabot** config updated if new deps added

---

## Approval

- [ ] **Self-review** completed by author before requesting review
- [ ] **At least one approval** from maintainer
- [ ] **No unresolved conversations** on PR
- [ ] **Branch up to date** with main (rebase/merge)
- [ ] **Single logical commit** or clean history (squash if needed)

---

## Quick Reference: Common Issues

| Issue | Fix |
|-------|-----|
| `SC2086` Double quote to prevent globbing | `"$VAR"` |
| `SC2155` Declare and assign separately | `local var; var=$(cmd)` |
| `SC2164` Use `cd ... || exit` | `cd "$dir" || die EX_IOERR "cd failed"` |
| `SC2034` Unused variable | Remove or `local _var=...` |
| `SC2254` Quote case patterns | `case "$var" in "pattern")` |
| `SC1091` Not following sourced file | Add `# shellcheck disable=SC1091` with comment |
| Magic exit code `exit 1` | Use `die EX_SOFTWARE "message"` |

---

*Last updated: 2026-09-20*
*Version: 1.0*