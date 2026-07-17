# Developer Workstation Framework

> An engineering-first framework for building, managing, validating, and evolving a professional macOS development workstation using modern Bash engineering practices.

![Platform](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Shell](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnu-bash)
![CI](https://img.shields.io/github/actions/workflow/status/SunnyJayaRaju/workstation-framework/quality.yml?branch=main&label=CI)
![License](https://img.shields.io/github/license/SunnyJayaRaju/workstation-framework)
![Version](https://img.shields.io/badge/version-v1.0.0-blue)

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

Instead of treating infrastructure as a collection of scripts, the repository treats it as software.

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
- ANSI color handling

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

- Bootstrapping a workstation
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

---

## Quality Assurance

Every change is verified using:

- Bash syntax validation
- ShellCheck static analysis
- shfmt formatting verification
- Automated Bats behavioral tests
- GitHub Actions Continuous Integration

---

## Documentation-Driven Development

Documentation is treated as part of the codebase.

The repository includes:

- Architecture documentation
- Coding standards
- Review checklist
- Roadmap
- AI handover documentation
- Project knowledge base
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

| Category | Technology |
|-----------|------------|
| Operating System | macOS |
| Shell | Bash |
| Version Control | Git |
| Repository Hosting | GitHub |
| CI/CD | GitHub Actions |
| Testing | Bats |
| Static Analysis | ShellCheck |
| Formatting | shfmt |
| Editor | Visual Studio Code |
| Documentation | Markdown |

---

# Current Release

**Version:** **v1.0.0**

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
├── examples/               # Usage examples (future)
├── scripts/
│   ├── lib/                # Shared Bash libraries
│   ├── backup.sh
│   ├── bootstrap.sh
│   ├── check-project.sh
│   ├── clean.sh
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

Bootstrap the framework:

```bash
./scripts/bootstrap.sh
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

| Script | Description |
|---------|-------------|
| `backup.sh` | Create timestamped backups of supported configuration files. |
| `bootstrap.sh` | Prepare the framework after cloning the repository. |
| `check-project.sh` | Validate repository structure and required project files. |
| `clean.sh` | Remove temporary development artifacts safely. |
| `doctor.sh` | Diagnose framework and workstation health. |
| `install.sh` | Install framework utilities into the local environment. |
| `restore.sh` | Restore the most recent configuration backup. |
| `shell-quality.sh` | Run Bash validation, ShellCheck, and formatting checks. |
| `sync.sh` | Verify synchronization with the remote Git repository. |
| `uninstall.sh` | Remove framework utilities from the local system. |
| `update.sh` | Update an installed framework and perform validation. |

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

| Command | Purpose |
|----------|---------|
| `make all` | Execute the complete quality gate. |
| `make test` | Run the Bats test suite. |
| `make lint` | Run ShellCheck validation. |
| `make doctor` | Execute workstation diagnostics. |
| `make check` | Verify repository structure. |

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
- Bootstrap
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

- **24 automated tests**
- **0 failures**

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
- Project Roadmap
- AI Handover Guide
- Project Knowledge

---

# Roadmap

## Version 1.x

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
