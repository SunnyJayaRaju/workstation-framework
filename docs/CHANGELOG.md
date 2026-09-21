# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/) and follows Semantic Versioning.

---

## [2.1.0] - 2026-09-21

### Fixed

1. **bootstrap.sh removed** — Pure duplication of install.sh with no added value. Eliminated confusion and maintenance burden.

2. **doctor.sh now exits non-zero on failures** — Added failure tracking; log_fail calls increment counter; main() exits 1 if any check failed. Previously printed "✗" but always exited 0.

3. **doctor.sh excludes install.sh/update.sh from installed execution check** — install.sh is the installer (not installed); update.sh requires install.sh. Fixed false "✗ install.sh" and "✗ update.sh execution failed" post-install.

4. **uninstall.sh discovers INSTALL_DIR from marker file** — install.sh writes .install_dir marker; uninstall.sh reads it before loading config. Fixes silent failure when custom INSTALL_DIR used without env var.

5. **Config precedence verified** — Environment variables correctly override user.conf and default.conf (env var > user.conf > default.conf). Matches documented precedence and least-surprise CLI behavior.

6. **backup.sh creates files with mode 600** — Added chmod 600 after cp to ensure backups are owner-readable/writable only.

7. **check-project.sh and repo-clean.sh operate from repository root** — check-project.sh cds to repo root before checks; repo-clean.sh already used PROJECT_ROOT; added documentation header describing scope.

8. **config/default.conf $HOME expansion fixed** — default.conf used `: ${VAR:=value}` syntax ignored by parser; rewrote to plain KEY=VALUE, added safe_expand() in config.sh. Default install no longer creates literal $HOME/.local/bin directory.

9. **config/default.conf dead code removed** — Removed hardcoded fallback block in load_config(); default.conf is now the sole source of truth.

10. **installed backup.sh/restore.sh config-copy fix** — install.sh now copies config/ to INSTALL_DIR/../config so installed scripts find default.conf. Fixed "Required environment variable not set: BACKUP_DIR" crash.

11. **require_var missing $ fix** — Five call sites passed bare exit-code name (EX_CONFIG) instead of $EX_CONFIG, causing "numeric argument required" crash. Fixed all call sites in install.sh, backup.sh, restore.sh, uninstall.sh.

12. **secrets.sh wired as documented public API** — lib/secrets.sh was dead code; now documented in ARCHITECTURE.md with 7 contract tests.

### Added

- Failure-path tests for doctor.sh, check-project.sh, and install.sh (missing .git, bad INSTALL_DIR, missing dependencies)
- CI steps for `make check` and `make doctor` to exercise these targets
- Test for installed backup.sh working from installed location
- 7 contract tests for secrets.sh (env fallback, Keychain round-trip, injection blocking)

### Changed

- Removed bootstrap.sh entirely (was zero-value wrapper)
- Removed bootstrap.sh tests and references from README
- Updated uninstall.sh to read .install_dir marker file
- Updated install.sh to write .install_dir marker file and copy config/ directory
- All --version outputs now read from VERSION file dynamically
- Single source of truth for version: VERSION file (2.1.0)
- Renamed checks.sh predicates to check_command_exists, check_file_exists, etc. to avoid collision with errors.sh

---

## [2.0.0] - 2026-09-21

### Fixed

1. **bootstrap.sh removed** — Pure duplication of install.sh with no added value. Eliminated confusion and maintenance burden.

2. **doctor.sh now exits non-zero on failures** — Added failure tracking; log_fail calls increment counter; main() exits 1 if any check failed. Previously printed "✗" but always exited 0.

3. **doctor.sh excludes install.sh/update.sh from installed execution check** — install.sh is the installer (not installed); update.sh requires install.sh. Fixed false "✗ install.sh" and "✗ update.sh execution failed" post-install.

4. **uninstall.sh discovers INSTALL_DIR from marker file** — install.sh writes .install_dir marker; uninstall.sh reads it before loading config. Fixes silent failure when custom INSTALL_DIR used without env var.

5. **Config precedence verified** — Environment variables correctly override user.conf and default.conf (env var > user.conf > default.conf). Matches documented precedence and least-surprise CLI behavior.

6. **backup.sh creates files with mode 600** — Added chmod 600 after cp to ensure backups are owner-readable/writable only.

7. **check-project.sh and repo-clean.sh operate from repository root** — check-project.sh cds to repo root before checks; repo-clean.sh already used PROJECT_ROOT; added documentation header describing scope.

### Added

- Failure-path tests for doctor.sh, check-project.sh, and install.sh (missing .git, bad INSTALL_DIR, missing dependencies)
- CI steps for `make check` and `make doctor` to exercise these targets

### Changed

- Removed bootstrap.sh entirely (was zero-value wrapper)
- Removed bootstrap.sh tests and references from README
- Updated uninstall.sh to read .install_dir marker file
- Updated install.sh to write .install_dir marker file

---

## [1.0.0] - 2026-07-17

### Added

- Initial Developer Workstation Framework project structure.
- Modular Bash utility architecture.
- Shared libraries for logging, validation, configuration, filesystem operations, and ANSI colors.
- Centralized configuration system with default, user, and environment variable support.
- Bootstrap, installation, update, uninstall, cleanup, synchronization, doctor, backup, restore, project verification, and shell quality utilities.
- GitHub Actions workflow for continuous integration.
- Automated Bats behavioral test suite.
- Project documentation covering architecture, roadmap, coding standards, review checklist, AI handover, and project knowledge.
- VS Code workspace recommendations.
- Project templates for future utility development.

### Changed

- Refactored utilities to reuse shared libraries.
- Standardized logging and validation across all scripts.
- Improved installer architecture and maintainability.
- Unified configuration loading throughout the framework.
- Improved backup and restore reliability.
- Updated README with complete project documentation.
- Improved repository organization and engineering consistency.

### Fixed

- Configuration precedence now correctly honors environment variables.
- Backup and restore workflows are fully testable.
- CI failures caused by configuration overrides.
- Shell formatting inconsistencies.
- Minor documentation inconsistencies discovered during repository audit.

---

## Future Releases

Future releases will continue to follow Semantic Versioning and Keep a Changelog conventions.