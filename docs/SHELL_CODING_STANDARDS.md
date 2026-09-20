# Shell Coding Standards

This document defines the coding standards for all Bash scripts in the Developer Workstation Framework. These standards ensure consistency, readability, and maintainability across the codebase.

---

## File Headers

Every script file must begin with a standardized header:

```bash
#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Script: <script-name>.sh
# Version: <semver>
#
# Purpose:
#   <One-line description of what this script does>
###############################################################################
```

- Use `#!/usr/bin/env bash` for portability
- Always include `set -euo pipefail`:
  - `-e`: Exit on error
  - `-u`: Treat unset variables as error
  - `-o pipefail`: Fail pipeline if any command fails
- Header block includes: Script name, Version (SemVer), Purpose
- Update Version on every behavioral change

---

## Naming Conventions

### Files and Directories
- Scripts: `kebab-case.sh` (e.g., `backup.sh`, `shell-quality.sh`)
- Libraries: `kebab-case.sh` in `scripts/lib/` (e.g., `logging.sh`, `errors.sh`)
- Tests: `<script-name>.bats` (e.g., `backup.bats`)
- Config: `*.conf` (e.g., `default.conf`, `user.conf`)

### Variables
- **Environment/Config**: `UPPER_SNAKE_CASE` (e.g., `INSTALL_DIR`, `BACKUP_DIR`)
- **Local variables**: `lower_snake_case` (e.g., `local backup_file`)
- **Constants**: `UPPER_SNAKE_CASE` with `readonly` (e.g., `readonly MAX_RETRIES=3`)
- **Loop iterators**: Short but descriptive (e.g., `for utility in ...`)

### Functions
- **Public functions**: `lower_snake_case` (e.g., `install_utility`, `load_config`)
- **Private/internal functions**: Prefix with `_` (e.g., `_parse_config_file`)
- **Boolean predicates**: Prefix with `is_`, `has_`, `can_` (e.g., `is_tty`, `has_op_cli`)

---

## Variables

### Declaration and Assignment
```bash
# Good
local backup_dir="${HOME}/.workstation/backups"
readonly BACKUP_DIR="${backup_dir}"

# Avoid
BACKUP_DIR=${HOME}/.workstation/backups  # No quotes, no local/readonly
```

### Expansion and Quoting
- **Always quote variable expansions**: `"$VAR"` not `$VAR`
- **Use `${VAR:-default}`** for defaults, `${VAR:=default}` for assignment
- **Use `${VAR:+value}`** for conditional expansion
- **Avoid unquoted expansions** in `[[ ]]` and `[ ]` (safe inside `[[ ]]` but quote anyway)

### Arrays
```bash
# Declare explicitly
local -a my_array=()
readonly MY_ARRAY=(item1 item2 item3)

# Iterate safely
for item in "${MY_ARRAY[@]}"; do
    echo "$item"
done
```

---

## Constants

- Use `readonly` for all constants
- Group related constants together
- Use descriptive names with units if applicable

```bash
readonly MAX_RETRIES=3
readonly RETRY_DELAY_SECONDS=2
readonly CONFIG_DIR="/etc/myapp"
readonly LOG_LEVEL_INFO=2
```

---

## Functions

### Structure
```bash
function_name() {
    local arg1="$1"
    local arg2="${2:-default}"

    # Validate inputs
    [[ -n "$arg1" ]] || die EX_USAGE "arg1 is required"

    # Do work
    do_something "$arg1" "$arg2"
}
```

### Rules
- **One function per logical task** — keep functions small (< 50 lines)
- **Declare all locals at top** — `local var1 var2 var3`
- **Validate inputs early** — use `die` from `errors.sh`
- **Return meaningful exit codes** — use `errors.sh` constants
- **Avoid global state** — pass data via arguments, not globals
- **Use `die` for fatal errors** — never `exit 1` directly

### Return Values
- **Exit codes**: Use `errors.sh` constants (`EX_OK`, `EX_USAGE`, etc.)
- **Output values**: Print to stdout, capture with `var=$(func)`
- **Error messages**: Print to stderr via `log_error` or `log_fail`

---

## Formatting

### Indentation
- **4 spaces** — no tabs
- **Continuation lines**: Indent 4 spaces from opening paren
```bash
if [[ "$condition1" == "value" ]] \
    && [[ "$condition2" == "value" ]]; then
    do_something
fi
```

### Line Length
- **Soft limit**: 100 characters
- **Hard limit**: 120 characters
- Break long lines at logical points (after `&&`, `|`, `,`)

### Braces and Keywords
```bash
# Good
if [[ -f "$file" ]]; then
    echo "Found"
else
    echo "Not found"
fi

# Function definition
my_function() {
    echo "Hello"
}
```

### Spacing
- Space after `(` and before `)` in `[[ ]]`, `(( ))`, `if`, `for`, `while`
- Space around operators: `=`, `==`, `!=`, `&&`, `||`, `-eq`, `-lt`
- No space inside `$( )` or `{ }` expansions

---

## Comments

### File/Function Comments
- **File header**: Required (see File Headers)
- **Function comments**: For non-obvious functions, explain:
  - What it does
  - Arguments
  - Return value
  - Side effects

```bash
# Parse a config file safely - only allows KEY=VALUE lines
# Arguments:
#   $1 - file path
#   $2 - optional prefix for variable names
# Returns:
#   0 on success, 1 on error
parse_config_file() { ... }
```

### Inline Comments
- Use sparingly — code should be self-documenting
- Explain **why**, not **what**
- Place on separate line above the code

```bash
# Retry with exponential backoff for transient network failures
retry 3 2 curl -sf "$url"
```

---

## Error Handling

### Mandatory Patterns
1. **`set -euo pipefail`** at top of every script
2. **Source `errors.sh`** for standardized error codes
3. **Use `die` for fatal errors**:
   ```bash
   source "${SCRIPT_DIR}/lib/errors.sh"
   [[ -f "$file" ]] || die EX_NOINPUT "File not found: $file"
   ```
4. **Check command availability**:
   ```bash
   require_command "git" EX_UNAVAILABLE
   ```
5. **Validate required variables**:
   ```bash
   require_var "INSTALL_DIR" EX_CONFIG
   ```

### Retry Logic
Use `retry` from `errors.sh` for transient failures:
```bash
retry 3 2 git fetch origin
```

---

## Logging

### Required Library
All scripts must source `logging.sh`:
```bash
source "${SCRIPT_DIR}/lib/logging.sh"
```

### Log Levels
Use appropriate level functions:
- `log_error` — Critical failures (stderr)
- `log_warn` — Recoverable issues
- `log_info` — General progress (default)
- `log_debug` — Verbose debugging (LOG_LEVEL=3)
- `log_pass` — Success checkmarks
- `log_fail` — Failure X marks

### Output Format
- Default: `[LEVEL] message` (colors on TTY)
- JSON: Set `LOG_FORMAT=json`
- Timestamped: Set `LOG_FORMAT=timestamped`

---

## Exit Codes

Use `errors.sh` constants exclusively:

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | `EX_OK` | Success |
| 64 | `EX_USAGE` | Usage error |
| 65 | `EX_DATAERR` | Data format error |
| 66 | `EX_NOINPUT` | Cannot open input |
| 69 | `EX_UNAVAILABLE` | Service unavailable |
| 70 | `EX_SOFTWARE` | Internal software error |
| 71 | `EX_OSERR` | System error |
| 72 | `EX_OSFILE` | Critical OS file missing |
| 74 | `EX_IOERR` | I/O error |
| 77 | `EX_NOPERM` | Permission denied |
| 78 | `EX_CONFIG` | Configuration error |

---

## Testing

### Test File Naming
- `<script-name>.bats` in `tests/`
- One test file per script

### Test Structure
```bash
#!/usr/bin/env bats

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export MY_VAR="test"
    mkdir -p "$HOME"
}

teardown() {
    rm -rf "$HOME"
}

@test "script.sh does something" {
    run ./scripts/script.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

### Test Requirements
- **Every script has tests** — at minimum: success path, error path, idempotency
- **Test behavior, not implementation** — test outputs, not internal variables
- **Use `setup`/`teardown`** for isolation
- **Use `BATS_TEST_TMPDIR`** for temporary files
- **Integration tests** in `tests/integration.bats`

---

## Quality Gates

Every commit must pass:

```bash
make all
```

Which runs:
1. **ShellCheck** — Static analysis (`shellcheck`)
2. **Formatting** — `shfmt -d -i 4 -ci`
3. **Syntax** — `bash -n`
4. **Tests** — `bats tests`
5. **Doctor** — `./scripts/doctor.sh`
6. **Structure** — `./scripts/check-project.sh`

### Pre-commit Checklist
- [ ] `make lint` passes
- [ ] `make format` produces no changes
- [ ] `make test` passes
- [ ] `make doctor` passes
- [ ] `make check` passes
- [ ] Documentation updated if behavior changed
- [ ] CHANGELOG.md updated

---

## Tool Versions

Pin tool versions in CI (`.github/workflows/quality.yml`):
- Bash: System default (macOS/Ubuntu)
- ShellCheck: Latest stable
- shfmt: Latest stable
- Bats: Latest stable (bats-core)