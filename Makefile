.PHONY: test lint format doctor check clean

test:
	bats tests

lint:
	find scripts templates -type f -name "*.sh" -exec shellcheck {} +

format:
	find scripts templates -type f -name "*.sh" -exec shfmt -w -i 4 -ci {} +

doctor:
	./scripts/doctor.sh

check:
	./scripts/check-project.sh

clean:
	./scripts/clean.sh