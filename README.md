# Developer Workstation Framework

> An engineering-first framework for building, managing, validating, and evolving a professional macOS development workstation using modern Bash engineering practices.

![Platform](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Shell](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnu-bash)
![CI](https://img.shields.io/github/actions/workflow/status/SunnyJayaRaju/workstation-framework/quality.yml?branch=main&label=CI)
![ShellCheck](https://img.shields.io/badge/ShellCheck-enabled-4EAA25?logo=shellcheck&logoColor=white)
![Bats](https://img.shields.io/badge/Bats-enabled-4EAA25?logo=bats&logoColor=white)
![License](https://img.shields.io/github/license/SunnyJayaRaju/workstation-framework)
![Version](https://img.shields.io/badge/version-v2.3.0-blue)

---

## Overview

Developer Workstation Framework is a structured, engineering-focused toolkit for building and maintaining a reproducible macOS development environment.

Rather than collecting standalone shell scripts over time, this project treats workstation management as a software engineering discipline. Every utility follows common coding standards, centralized configuration, reusable libraries, automated validation, behavioral testing, and continuous integration.

The result is a framework that is easier to understand, extend, maintain, and confidently evolve over time.

---

# Why This Project?

Most workstation setup repositories eventually become difficult to maintain because they evolve organically:

- Scripts become duplicated.
- Configuration is scattered.
- Documentation falls behind implementation.
- Validation becomes manual.
- Small changes introduce regressions.

Developer Workstation Framework addresses these problems by organizing workstation automation into a maintainable engineering project with clearly separated responsibilities.

Instead of treating infrastructure as a collection of scripts, the repository treats it as real software.

---

# Design Philosophy

The framework is guided by several engineering principles.

## Reusability

Common functionality belongs in shared libraries instead of being duplicated across utilities.

## Simplicity

Each script should perform one responsibility well.

## Maintainability

Readable code is preferred over clever code.

## Automation

Quality verification should be automated whenever possible.

## Consistency

Every utility follows the same project structure, coding standards, logging style, and validation process.

## Reliability

Configuration, testing, and validation should produce deterministic results both locally and in continuous integration environments.

---

# Key Features

## Modular Bash Architecture

Shared libraries eliminate duplicated logic and provide reusable functionality for:

- Logging
- Configuration loading
- Filesystem operations
- Validation helpers
- Backup path and manifest handling
- ANSI color output (owned by the logging library)

---

## Centralized Configuration

Configuration is managed through dedicated configuration files with predictable precedence.

Priority order:

1. Environment variables
2. `config/user.conf`
3. `config/default.conf`

This allows local customization without modifying repository defaults while remaining friendly to CI pipelines.

---

## Built-in Utilities

The framework includes utilities for:

- Installing framework utilities
- Updating installations
- Removing installations
- Repository synchronization
- Configuration backup
- Configuration restore
- Repository verification
- Framework diagnostics
- Cleanup
- Shell quality validation

### Where the utilities are installed

`install.sh` writes every utility to `INSTALL_DIR`, which defaults to
`~/.local/bin`. That directory must be on your `PATH` for the utilities to be
runnable by name; `doctor.sh` reports what it finds, and `update.sh`
reinstalls in place. See `config/default.conf` for `INSTALL_DIR`.

---

## Quality Assurance

Every change is verified using:

- Bash syntax validation
- ShellCheck static analysis
- shfmt formatting verification
- Automated Bats behavioral tests
- GitHub Actions Continuous Integration

### Reproducing CI locally

- `make ci-local` prints your `bash`, `bats`, `shellcheck` and `shfmt` versions, warns when they differ from CI's pins, then runs CI's steps in order: `syntax`, `shellcheck -x`, `shfmt -d -i 4 -ci`, `bats tests`, `make check`, `make doctor`.
- `make test-bash32` runs the whole suite under `/bin/bash`, which is bash 3.2 on macOS; it skips with a message on systems without `/bin/bash`.
- The zsh guard lives at `templates/guard.zsh`; `install.sh` does not touch your shell files. To activate it: `cp templates/guard.zsh ~/.config/zsh/guard.zsh`, then `echo 'source ~/.config/zsh/guard.zsh' >> ~/.zshrc`.
- `make verify-machine` is **not** part of CI: it compares the guard installed at `~/.config/zsh/guard.zsh` against `templates/guard.zsh` and checks that topgrade really has both gem steps disabled, reporting MATCH or DIFFERENT.
- `make verify-protection` is also local and read-only: it asks GitHub what `main`'s branch protection requires and compares it with `.github/required-checks.txt`, because those two drifting apart makes a green PR unmergeable.
- It is read-only and repairs nothing; run it when you want to know whether this machine still matches the repository.
- The first two mirror `.github/workflows/quality.yml`; if CI is red, run them before pushing.

---

## Documentation-Driven Development

Documentation is treated as part of the codebase.

The repository includes:

- Architecture documentation
- Coding standards
- Security policy (SECURITY.md)
- Commit conventions (docs/COMMIT_CONVENTION.md)
- Review checklist
- Changelog

---

## Engineering Workflow

Development follows a consistent lifecycle:

```text
Design
    ↓
Implement
    ↓
Validate
    ↓
Test
    ↓
Review
    ↓
Release
```

---

# Technology Stack

| Category           | Technology         |
| ------------------ | ------------------ |
| Operating System   | macOS              |
| Shell              | Bash               |
| Version Control    | Git                |
| Repository Hosting | GitHub             |
| CI/CD              | GitHub Actions     |
| Testing            | Bats               |
| Static Analysis    | ShellCheck         |
| Formatting         | shfmt              |
| Editor             | Visual Studio Code |
| Documentation      | Markdown           |

---

# Current Release

**Version:** **v2.3.0**

### Highlights

- Modular Bash architecture
- Shared utility libraries
- Centralized configuration management
- Automated behavioral testing
- Continuous Integration
- Engineering documentation
- Reusable workstation utilities
- Production-ready project structure

---

# Repository Structure

```text
workstation-framework/
├── .github/                # GitHub workflows, templates, CODEOWNERS
├── .vscode/                # Recommended VS Code configuration
├── assets/                 # Project assets
├── config/                 # Framework configuration
│   ├── default.conf
│   ├── example.conf
│   └── user.conf
├── docs/                   # Project documentation
├── scripts/
│   ├── lib/                # Shared Bash libraries
│   ├── backup.sh
│   ├── check-project.sh
│   ├── repo-clean.sh
│   ├── doctor.sh
│   ├── install.sh
│   ├── restore.sh
│   ├── shell-quality.sh
│   ├── sync.sh
│   ├── uninstall.sh
│   └── update.sh
├── templates/              # Script templates
├── tests/                  # Automated Bats tests
├── Makefile
├── README.md
└── LICENSE
```

The repository is intentionally organized to separate framework logic, reusable libraries, configuration, documentation, testing, and project assets.

---

# Prerequisites

Developer Workstation Framework currently targets macOS.

Required tools:

- Bash
- Git
- ShellCheck
- shfmt
- jq (required by the 1Password backend in `scripts/lib/secrets.sh`)
- Bats (for development and testing)

Recommended:

- Visual Studio Code
- Homebrew

---

# Installation

Clone the repository:

```bash
git clone https://github.com/SunnyJayaRaju/workstation-framework.git

cd workstation-framework
```

Install the framework:

```bash
./scripts/install.sh
```

Verify the installation:

```bash
./scripts/doctor.sh
```

---

# Configuration

Framework configuration is stored in the `config/` directory.

```
config/
├── default.conf
├── example.conf
└── user.conf
```

Configuration precedence follows standard Unix conventions:

```text
Environment Variables
        │
        ▼
config/user.conf
        │
        ▼
config/default.conf
```

This allows:

- sensible project defaults
- local machine customization
- CI/CD overrides
- temporary runtime overrides

Example:

```bash
BACKUP_DIR=/tmp/framework-backups ./scripts/backup.sh
```

No repository files need to be modified for temporary configuration changes.

---

# Available Utilities

| Script             | Description                                                                                                                       |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `backup.sh`        | Create timestamped backups of supported configuration files.                                                                      |
| `check-project.sh` | Validate repository structure and required project files.                                                                         |
| `repo-clean.sh`    | Remove temporary development artifacts safely.                                                                                    |
| `doctor.sh`        | Diagnose framework and workstation health.                                                                                        |
| `install.sh`       | Install framework utilities into the local environment.                                                                           |
| `mac-routine.sh`   | Run topgrade, mo clean, brew doctor and brew cleanup in order, measuring root-owned files and the gem version between every step. |
| `restore.sh`       | Restore the most recent configuration backup.                                                                                     |
| `shell-quality.sh` | Run Bash validation, ShellCheck, and formatting checks.                                                                           |
| `sync.sh`          | Verify synchronization with the remote Git repository.                                                                            |
| `uninstall.sh`     | Remove framework utilities from the local system.                                                                                 |
| `update.sh`        | Update an installed framework and perform validation.                                                                             |

---

# Ruby and Homebrew: three rules

These exist because of a real event on **2026-09-16**. A RubyGems **4.0.21**
source tree — 591 files — was written into
`/opt/homebrew/lib/ruby/site_ruby/4.0.0/` with **root ownership**, at
`2026-09-16 14:48:56`. Homebrew's Ruby ships **4.0.20**, so that tree was an
override, not part of the keg. The root-owned files then blocked `brew link`
and `brew cleanup`, and the weekly routine could not finish.

**Which process issued that command is still unproven.** The zsh history has no
timestamps, its oldest per-session file begins 25 Sep, and macOS keeps no sudo
log. Do not repeat that claim as fact.

## 1. Never use `sudo` with `gem` or `brew`

```bash
brew install <name>     # yes
sudo gem install <name> # never: writes into /opt/homebrew as root
```

Homebrew owns Ruby's gems. `sudo gem` and `sudo brew` are refused by
`~/.config/zsh/guard.zsh`, which is loaded from `~/.zshrc`.

> **What the guard does NOT protect.** It covers commands **typed in an
> interactive shell**. It does **not** cover topgrade. Topgrade calls
> `/usr/bin/sudo -E -H .../gem update --system` as a **subprocess**: no shell
> function is inherited into it, so nothing in `guard.zsh` can stop it. Topgrade
> is protected by two other things, and only by those two:
>
> 1. `~/.config/topgrade.toml` disables the `gem` and `ruby_gems` steps.
> 2. `mac-routine.sh` records root-owned counts and `gem -v` between every step
>    and stops the routine if either changes.
>
> Any other program that shells out to sudo needs the same treatment.

If a root-owned file appears anyway, the fix — which needs your password — is:

```bash
sudo find /opt/homebrew -user root -exec chown -h "$(whoami)":admin {} +
```

## 2. Never run `gem update --system`

Against a Homebrew Ruby it installs a whole RubyGems source tree into
`site_ruby`, shadowing the one the keg ships. It is also the command the
interpreter's `ruby_gems` step runs under sudo.

Homebrew's Ruby ships RubyGems with the keg. Upgrade gems individually with
`gem install <name>`; upgrade Ruby with `brew upgrade ruby`.

If an override does appear, move it aside rather than deleting it:

```bash
TS=$(date +%Y%m%d-%H%M%S); mkdir -p ~/Developer/Backups/site_ruby-stale-$TS
mv /opt/homebrew/lib/ruby/site_ruby/* ~/Developer/Backups/site_ruby-stale-$TS/
# undo: mv ~/Developer/Backups/site_ruby-stale-$TS/* /opt/homebrew/lib/ruby/site_ruby/
```

## 3. Run the routine through `mac-routine.sh`

```bash
mac-routine.sh          # the real thing
mac-routine.sh --dry-run # measure only
```

It runs **topgrade → mo clean → brew doctor → brew cleanup** and, between
every step, records two numbers: how many files under `/opt/homebrew` and
`~/.gem` are owned by root, and what `gem -v` reports. If either changes it
**stops**, prints the step responsible, the new files, and the fix command.
Nothing after that step runs.

It never calls `sudo`. It passes topgrade `--no-ask-retry` so the
"Retry? (y)es/(N)o/(s)hell/(q)uit" prompt cannot hang it, and adds
`--disable containers` when no container runtime is answering.

### Bypassing the guard

The guard is bypassed with an explicit environment variable, deliberately and
per-invocation:

```bash
ALLOW_RISKY_GEM=1 sudo gem install <name>
```

Run `bash ~/Developer/Tools/scripts/verify-setup.sh` afterwards and read the
**Ruby/gem health** section.

### What the harness checks

`lib/ruby_gem_health.sh` is the single implementation, used by
`verify-setup.sh`, by `mac-routine.sh` between steps, and by
`tests/ruby-gem-guard.bats`. It reports:

| Verdict | Condition                                                                                                             |
| ------- | --------------------------------------------------------------------------------------------------------------------- |
| FAIL    | any root-owned file under `/opt/homebrew` or `~/.gem`                                                                 |
| FAIL    | `gem -v` differs from the RubyGems version the active Homebrew Ruby ships (means a `site_ruby` override)              |
| FAIL    | `site_ruby` contains files (an empty directory is healthy)                                                            |
| FAIL    | `brew doctor` reports an unlinked or unreadable keg                                                                   |
| FAIL    | a `~/.gem` plugin points at a path that no longer exists, or a `~/.gem` command's shebang names a missing interpreter |
| WARN    | two versions of the same gem inside `~/.gem` (Homebrew's bundled/default gems are excluded by design)                 |
| INFO    | the interpreter `~/.gem/ruby/*/bin` points at                                                                         |

Every FAIL prints the exact fix. **The harness never runs `sudo`** — it prints
the command and you run it.

---

# Development Workflow

Every contribution should follow the same engineering workflow.

```
Plan
 ↓
Implement
 ↓
Validate
 ↓
Test
 ↓
Review
 ↓
Commit
```

The objective is to maintain a repository where every change is reproducible, reviewable, and well documented.

---

# Development Commands

The project uses a Makefile to simplify routine tasks.

| Command       | Purpose                            |
| ------------- | ---------------------------------- |
| `make all`    | Execute the complete quality gate. |
| `make test`   | Run the Bats test suite.           |
| `make lint`   | Run ShellCheck validation.         |
| `make doctor` | Execute workstation diagnostics.   |
| `make check`  | Verify repository structure.       |

Before every commit, run:

```bash
make all
```

---

# Automated Testing

Behavioral testing is implemented using Bats.

Current coverage includes:

- Backup
- Restore
- Installation
- Update
- Uninstall
- Doctor
- Cleanup
- Repository verification
- Configuration
- Shell quality
- Repository synchronization

Current status:

- **`make test` passes with zero failures**

---

# Continuous Integration

Every push and pull request automatically runs:

- Bash syntax validation
- ShellCheck
- shfmt verification
- Automated Bats tests

This helps ensure that every change remains production ready.

---

# Documentation

Detailed project documentation is available in the `docs/` directory.

Included documentation:

- Architecture
- Changelog
- Coding Standards
- Code Review Checklist
- Commit Convention
- Security Policy

---

# Roadmap

## Future Enhancements

Future enhancements may include:

- Additional workstation automation
- Expanded backup support
- Cross-platform compatibility
- Enhanced diagnostics
- More behavioral tests
- Plugin-style utility extensions

The project will continue to prioritize maintainability, modularity, and engineering quality over rapid feature growth.

---

# Contributing

Contributions are welcome.

Please review:

- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`

Before submitting a Pull Request, ensure:

```bash
make all
```

passes successfully.

---

# License

This project is licensed under the MIT License.

See the `LICENSE` file for details.

---

# Acknowledgements

Developer Workstation Framework was built with a strong emphasis on software engineering principles rather than simple shell scripting.

The project focuses on:

- Clean architecture
- Maintainable Bash code
- Reusable libraries
- Automated quality validation
- Documentation-first development
- Continuous improvement

If you find the project useful, consider starring the repository and sharing feedback through GitHub Issues or Pull Requests.
