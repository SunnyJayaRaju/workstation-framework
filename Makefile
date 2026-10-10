.DEFAULT_GOAL := help

.PHONY: \
	all \
	help \
	test \
	test-bash32 \
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

syntax: ## Check Bash syntax of every script
	find scripts templates -type f -name "*.sh" -exec bash -n {} +

lint: ## Run ShellCheck
	find scripts templates -type f -name "*.sh" -exec shellcheck -x {} +

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