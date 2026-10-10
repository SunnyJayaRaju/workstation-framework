.DEFAULT_GOAL := help

.PHONY: \
	all \
	help \
	test \
	test-bash32 \
	verify-machine \
	verify-protection \
	ci-local \
	lint \
	format \
	doctor \
	check \
	clean \
	repo-clean \
	install \
	uninstall \
	syntax

all: syntax lint format test doctor check ## Run all quality checks

help: ## Show available commands
	@echo ""
	@echo "Developer Workstation Framework"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' Makefile | \
	awk 'BEGIN {FS=":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
	@echo ""
	@echo "lint uses the same flags as CI (.github/workflows/quality.yml):"
	@echo "  shellcheck -x, so local and CI cannot disagree again."
	@echo ""

test: ## Run all Bats tests
	bats tests

# The suite must also run under the bash that ships as /bin/bash on macOS,
# which is 3.2 - older than anything a Linux CI runner has. bats re-execs
# itself through `#!/usr/bin/env bash`, so the interpreter it uses is decided
# by PATH. Putting /bin first and calling bats by absolute path is enough to
# run the whole suite under 3.2; nothing is installed, moved or deleted.
test-bash32: ## Run the whole suite under /bin/bash (bash 3.2 on macOS)
	@if [ ! -x /bin/bash ]; then \
		echo "SKIPPED test-bash32: no /bin/bash on this system."; \
		echo "  It covers the bash 3.2 interpreter that macOS ships as /bin/bash."; \
		echo "  CI covers bash 5 on ubuntu-latest; neither is redundant."; \
		exit 0; \
	fi; \
	bats_bin="$$(command -v bats)"; \
	echo "interpreter : $$(/bin/bash --version | head -1)"; \
	echo "bats        : $$bats_bin"; \
	PATH="/bin:/usr/bin:$$PATH" "$$bats_bin" tests

# Reproduces .github/workflows/quality.yml locally, in the same order and with
# the same flags, so a red CI run can be diagnosed before pushing. The version
# pins below are the macOS leg's, because that is the runner a developer is
# standing on; the Ubuntu leg pins older ones (see the workflow).
ci-local: ## Reproduce CI locally: versions, then syntax, shellcheck, shfmt, bats, check, doctor
	@echo "=== tool versions (local) ==="
	@printf 'bash        : %s\n' "$$(bash --version | head -1)"
	@printf 'bats        : %s\n' "$$(bats --version)"
	@printf 'shellcheck  : %s\n' "$$(shellcheck --version | awk '/version:/ {print $$2}')"
	@printf 'shfmt       : %s\n' "$$(shfmt --version | sed 's/^v//')"
	@echo
	@echo "=== CI pins (.github/workflows/quality.yml, macOS leg) ==="
	@echo "bash        : 3.2 (via 'make test-bash32'; CI's Ubuntu leg is bash 5)"
	@echo "bats        : 1.14.0"
	@echo "shellcheck  : 0.11.0"
	@echo "shfmt       : 3.14.1"
	@echo
	@for pair in \
		"bats $$(bats --version | awk '{print $$NF}') 1.14.0" \
		"shellcheck $$(shellcheck --version | awk '/version:/ {print $$2}') 0.11.0" \
		"shfmt $$(shfmt --version | sed 's/^v//') 3.14.1"; do \
		set -- $$pair; \
		if [ "$$2" != "$$3" ]; then \
			echo "WARNING $$1 is $$2 here but CI pins $$3 - a difference here can hide a difference there."; \
		fi; \
	done
	@echo
	@echo "=== 1/6 syntax ==="        && $(MAKE) syntax
	@echo "=== 2/6 shellcheck -x ===" && $(MAKE) lint
	@echo "=== 3/6 shfmt -d ==="      && find scripts templates -type f -name "*.sh" -exec shfmt -d -i 4 -ci {} +
	@echo "=== 4/6 bats ==="          && bats tests
	@echo "=== 5/6 make check ==="    && $(MAKE) check
	@echo "=== 6/6 make doctor ==="   && $(MAKE) doctor
	@echo
	@echo "ci-local: all steps passed."

syntax: ## Check Bash syntax of every script, and zsh syntax of the guard
	find scripts templates -type f -name "*.sh" -exec bash -n {} +
	@if command -v zsh >/dev/null 2>&1; then \
		echo "zsh -n templates/guard.zsh"; \
		zsh -n templates/guard.zsh; \
	else \
		echo "SKIPPED zsh -n templates/guard.zsh: zsh is not installed on this machine."; \
		echo "  The guard cannot be syntax-checked without zsh. CI installs it."; \
	fi

lint: ## Run ShellCheck
	find scripts templates -type f -name "*.sh" -exec shellcheck -x {} +

# Read-only. NOT part of CI and NOT part of ci-local: it asserts the state of
# THIS machine, which is exactly what the suite stopped asserting so that it
# could run anywhere.
#
#   (a) the guard that runs here still matches the one in the repository
#   (b) topgrade really has both gem steps disabled here
#
# Neither check is allowed to repair anything. The whole point is to tell you
# the two have drifted, not to make them agree.
verify-machine: ## Check THIS machine's guard and topgrade config against the repo (read-only)
	@echo "=== (a) installed guard vs templates/guard.zsh ==="
	@installed="$$HOME/.config/zsh/guard.zsh"; \
	repo="templates/guard.zsh"; \
	hdr=17; \
	if [ ! -r "$$installed" ]; then \
		echo "  DIFFERENT: $$installed does not exist."; \
		echo "    nothing is installed; see the README for the two commands that activate the guard"; \
	elif tail -n +$$((hdr + 1)) "$$repo" | cmp -s - "$$installed"; then \
		echo "  MATCH: the installed guard is byte-identical to the repo copy below its $$hdr-line header"; \
	else \
		echo "  DIFFERENT: the installed guard has drifted from the repo copy."; \
		echo "    first differing line (repo vs installed):"; \
		awk -v h="$$hdr" 'FNR==NR { if (FNR > h) a[FNR-h] = $$0; next } { b[FNR] = $$0 } \
			END { n = (length(a) > length(b)) ? length(a) : length(b); \
			      for (i = 1; i <= n; i++) if (a[i] != b[i]) { \
			        printf "      line %d (repo body line %d):\n", i, i; \
			        printf "        repo:      %s\n", a[i]; \
			        printf "        installed: %s\n", b[i]; \
			        exit } \
			      print "        (files differ only in trailing content)" }' \
			"$$repo" "$$installed"; \
		echo "    to re-activate the repo version:"; \
		echo "      cp $$repo $$installed"; \
	fi
	@echo
	@echo "=== (b) topgrade config disables both gem steps ==="
	@cfg="$$HOME/.config/topgrade.toml"; \
	if [ ! -r "$$cfg" ]; then \
		echo "  UNKNOWN: no topgrade config at $$cfg"; \
	elif grep -qE '^[[:space:]]*disable[[:space:]]*=.*"gem"' "$$cfg" \
		&& grep -qE '^[[:space:]]*disable[[:space:]]*=.*ruby_gems' "$$cfg"; then \
		echo "  OK: 'gem' and 'ruby_gems' are both disabled in $$cfg"; \
	else \
		echo "  PROBLEM: $$cfg does not disable both gem steps."; \
		echo "    topgrade would reach for sudo gem update --system. Add them to disable:"; \
		echo "      disable = [\"gem\", \"ruby_gems\"]"; \
	fi
	@echo
	@echo "verify-machine: read-only. Nothing was changed."

# Read-only. NOT in CI and NOT in ci-local: it asks GitHub what branch
# protection actually requires, so it needs `gh`, network access, and a
# repository where that answer means something.
#
# Branch protection lists required status checks as plain strings. Nothing keeps
# them in step with the job names quality.yml produces, so renaming a runner
# silently makes every PR unmergeable while CI stays green.
verify-protection: ## Compare main's required status checks with .github/required-checks.txt (read-only)
	@file=".github/required-checks.txt"; \
	repo="SunnyJayaRaju/workstation-framework"; \
	if [ ! -r "$$file" ]; then echo "MISSING: $$file"; exit 1; fi; \
	if ! command -v gh >/dev/null 2>&1; then \
		echo "SKIPPED: gh is not installed, so branch protection cannot be read."; exit 1; \
	fi; \
	if ! gh auth status >/dev/null 2>&1; then \
		echo "SKIPPED: gh is not logged in, so branch protection cannot be read."; exit 1; \
	fi; \
	remote="$$(gh api "repos/$$repo/branches/main/protection/required_status_checks" --jq '.contexts[]' 2>/dev/null | sort)"; \
	if [ -z "$$remote" ]; then \
		echo "UNREADABLE: could not read the required status checks for main."; \
		echo "  (no protection rule on main, or no permission to read it)"; \
		exit 1; \
	fi; \
	recorded="$$(grep -v '^[[:space:]]*$$' "$$file" | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//' | sort)"; \
	echo "=== main's required status checks ==="; printf '%s\n' "$$remote" | sed 's/^/  /'; \
	echo "=== .github/required-checks.txt ==="; printf '%s\n' "$$recorded" | sed 's/^/  /'; \
	echo; \
	if [ "$$remote" = "$$recorded" ]; then \
		echo "MATCH: branch protection requires exactly what the file records."; \
	else \
		echo "DIFFERENT. Lines only in branch protection:"; \
		printf '%s\n' "$$remote" | while IFS= read -r c; do \
			[ -n "$$c" ] || continue; \
			printf '%s\n' "$$recorded" | grep -qxF "$$c" || echo "  - $$c"; \
		done; \
		echo "Lines only in .github/required-checks.txt:"; \
		printf '%s\n' "$$recorded" | while IFS= read -r c; do \
			[ -n "$$c" ] || continue; \
			printf '%s\n' "$$remote" | grep -qxF "$$c" || echo "  + $$c"; \
		done; \
		echo; \
		echo "  rename the required checks in branch protection AND update $$file."; \
		echo "  Until both agree, a green PR is unmergeable."; \
		exit 1; \
	fi

format: ## Format shell scripts
	find scripts templates -type f -name "*.sh" -exec shfmt -w -i 4 -ci {} +

doctor: ## Run workstation diagnostics
	./scripts/doctor.sh

check: ## Verify repository structure
	./scripts/check-project.sh

clean: ## Remove test and build artifacts
	rm -rf coverage reports .bats-tmp

repo-clean: ## Remove repository temporary files (orig, ~, .DS_Store)
	./scripts/repo-clean.sh

install: ## Install framework utilities
	./scripts/install.sh

uninstall: ## Uninstall framework utilities
	./scripts/uninstall.sh