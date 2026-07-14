# Contributing to Developer Workstation Framework

Thank you for your interest in contributing.

This project focuses on providing a clean, reliable, and maintainable developer workstation framework built with Bash and supporting tooling.

## Before You Start

Please ensure you have the following installed:

- Git
- Bash
- ShellCheck
- shfmt
- Bats

Clone the repository:

```bash
git clone https://github.com/SunnyJayaRaju/workstation-framework.git
cd workstation-framework
```

## Verify Your Environment

Run:

```bash
make all
```

This will execute:

- ShellCheck
- shfmt
- Bats tests
- Doctor checks
- Repository verification

All checks must pass before opening a Pull Request.

## Coding Standards

- Follow existing project structure.
- Use Bash best practices.
- Keep functions small and readable.
- Run ShellCheck before committing.
- Format scripts with shfmt.
- Add or update Bats tests whenever behavior changes.

## Pull Requests

Please:

- Keep pull requests focused.
- Explain why the change is needed.
- Reference related issues when applicable.
- Ensure GitHub Actions passes successfully.

## Reporting Issues

Use the provided GitHub Issue templates for:

- Bug reports
- Feature requests

For general questions or discussions, use GitHub Discussions.

Thank you for helping improve this project.
