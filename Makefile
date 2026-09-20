.DEFAULT_GOAL := help

.PHONY: \
	all \
	help \
	test \
	lint \
	format \
	doctor \
	check \
	clean \
	repo-clean \
	install \
	uninstall

all: lint format test doctor check ## Run all quality checks

help: ## Show available commands
	@echo ""
	@echo "Developer Workstation Framework"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## ' Makefile | \
	awk 'BEGIN {FS=":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
	@echo ""

test: ## Run all Bats tests
	bats tests

lint: ## Run ShellCheck
	find scripts templates -type f -name "*.sh" -exec shellcheck {} +

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