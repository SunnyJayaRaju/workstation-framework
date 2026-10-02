# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/) and follows Semantic Versioning.

---

## [2.2.0] - 2026-10-02

Minor bump. Substantial new behaviour (backup integrity verification) and a
large body of fixes, but no breaking interface change: `backup.sh` and
`restore.sh` keep their existing flags and environment variables, and
backups taken before this release still restore.

The guiding theme of this release is that the framework had checks that could
not fail. Several safeguards existed only on paper -- an `assert` helper with
no callers, a verification harness invoking a flag that never existed, a
standards document mandating a versioning scheme nothing used -- so a test
suite could be comprehensively green while a data-loss bug sat in
`restore.sh`. Each item below is a case where a check was made to actually
exercise the behaviour it claimed to cover.

### Backup and restore integrity

- **Backups are now recorded and verified.** Each run of `backup.sh` writes
  a `manifest_<timestamp>.json` recording the backup filename, source path and
  a SHA-256 of the copied content. `restore.sh` verifies a backup against its
  manifest before overwriting anything; a mismatch names the file, refuses it,
  and continues with the remaining sources. `--dry-run` reports the same
  verdict, so it cannot be used to discover that a corrupt backup *would*
  have been installed. Manifests are written `600` via a temp file and rename,
  so a reader never sees a partial one, and a run that failed partway writes
  none.

- **A manifest cannot redirect a write.** It is read as text, never evaluated,
  and only a digest is taken from it; the destination always comes from
  `BACKUP_SOURCES`. A tampered manifest can force a refusal but cannot cause a
  file to be written elsewhere. This property has a test that fails when
  broken.

- **A 0-byte backup is refused outright.** Checked before the manifest is
  consulted, because the SHA-256 of empty content is a fixed constant: a
  manifest written for an empty backup matches it perfectly, so the hash check
  alone could never catch this.

- **Safety copies can no longer overwrite each other.** The pre-restore safety
  copy is what makes a restore reversible, yet its name had one-second
  resolution, so two restores of one source inside the same second destroyed
  the first copy. Measured before: one copy in four runs out of five. After:
  two in five out of five. A symlink at the chosen name is still refused
  rather than skipped past, preserving the fail-closed behaviour.

- **Legacy backups still restore.** Any backup predating manifests lacks one
  and is restored with a notice rather than refused; refusing them would
  strand real backups.

- **Backup naming and permissions.** Backups are keyed on the source path
  relative to `$HOME` rather than basename, so `~/.ssh/config` and a top-level
  `~/config` no longer share one backup file. `BACKUP_SOURCES` accepts a
  newline-separated list for paths containing spaces, and a token that looks
  like a split space-containing path is warned about. Backup files are written
  `600` by `install -m 600`, removing the window in which a copy of
  `~/.ssh/config` existed at the source's mode. `BACKUP_DIR` itself is
  tightened to `700`, and any pre-existing permissive store is tightened too.

### Destructive-path safety

- **Path validation before deletion.** `uninstall.sh` validates its
  install directory before removing anything and fails closed on `/`, `//`,
  relative paths, and top-level paths such as `/usr/local`.
- **Only named artefacts are removed** outside `INSTALL_DIR`, and only after
  that validation. The install marker, `config/` and `VERSION` are the only
  paths ever touched.
- **Test isolation.** The destructive-path tests resolve paths from the test's
  own temporary directory, so a regression cannot delete a real dotfile.
  A logging `rm` stub asserts that no removal was even *attempted*.
- **`repo-clean.sh` no longer treats an installed copy as a scratch tree**, and
  reports honest failures instead of claiming success.

### Secrets handling

- `lib/secrets.sh` was dead code with a real contract; it is now wired,
  documented and covered by tests. Call sites document that item names may be
  visible in process listings, and the 1Password read path fails loudly when
  `jq` is absent rather than silently falling through to a different backend.

### Diagnostics and correctness

- **Systematic exit codes.** `die` call sites pass a `die "$EX_*"` *value*
  where they had passed a bare name, which produced "numeric argument
  required" crashes instead of the intended code.
- **Absent tools are reported as an incomplete environment**, never as a lint
  failure, so a missing ShellCheck cannot be mistaken for a code defect.
- `update.sh` parses arguments properly, skips `git pull` gracefully with no
  upstream or in detached HEAD, and `make syntax` gates every batch.
- `sync.sh` retries its fetch and explains an unreachable remote in its own
  words instead of leaking git's stderr; it documents that it prunes.
- `check-project.sh` reports every failure in one pass instead of aborting at
  the first, and checks `VERSION`, `Makefile`, `config`, required utilities and
  each of the ten utility scripts by name.

### CI

- Tool versions are **pinned** and asserted: exact apt versions on Ubuntu, and
  an explicit version check after `brew install` on macOS, since Homebrew has
  no per-version pin. `bats_require_minimum_version` is declared rather than
  left to warn.

### Documentation and dead code

- The shell coding standards documented a per-script SemVer header that no
  script had used since 2.1.0; it now describes the single `VERSION` file the
  whole project actually uses.
- Removed: the unused `eval`-based `assert` helper, two existence predicates
  with zero call sites, and `lib/colors.sh`, whose constants were used by none
  of the six scripts that sourced it and were already provided by
  `logging.sh`.
- `doctor.sh` now checks `bats` and reports whether the installed `VERSION`
  still matches the source, which is what previously let the live machine run
  several releases behind unnoticed.

---

## [2.1.0] - 2026-09-21

### Fixed

1. **config/default.conf $HOME expansion fixed** — default.conf used `: ${VAR:=value}` syntax ignored by parser; rewrote to plain KEY=VALUE, added safe_expand() in config.sh. Default install no longer creates literal $HOME/.local/bin directory.

2. **config/default.conf dead code removed** — Removed hardcoded fallback block in load_config(); default.conf is now the sole source of truth.

3. **installed backup.sh/restore.sh config-copy fix** — install.sh now copies config/ to INSTALL_DIR/../config so installed scripts find default.conf. Fixed "Required environment variable not set: BACKUP_DIR" crash.

4. **require_var missing $ fix** — Five call sites passed bare exit-code name (EX_CONFIG) instead of $EX_CONFIG, causing "numeric argument required" crash. Fixed all call sites in install.sh, backup.sh, restore.sh, uninstall.sh.

5. **secrets.sh wired as documented public API** — lib/secrets.sh was dead code; now documented in ARCHITECTURE.md with 7 contract tests.

6. **--version works on installed scripts** — install.sh now copies VERSION file to INSTALL_DIR/../VERSION; all scripts handle missing VERSION file gracefully with clean error message and non-zero exit.

7. **checks.sh Version header added** — Added "# Version: see VERSION file" header to match other lib files.

### Added

- Test for installed backup.sh working from installed location (tests/backup.bats)
- Version header consistency across all lib files

### Changed

- install.sh now copies VERSION file to INSTALL_DIR/../VERSION
- All --version outputs now read from VERSION file dynamically with proper error handling
- All scripts handle missing VERSION file gracefully with clean error message and non-zero exit
- Fixed shellcheck SC2155 warnings by separating declare and assign

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
- Project documentation covering architecture, roadmap, coding standards, review checklist, and project knowledge.
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