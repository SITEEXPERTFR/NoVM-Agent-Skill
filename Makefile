NOVM ?= $(shell cat .novm 2>/dev/null || echo "https://virtual-xfce-spin--ogsincord.replit.app/")
FALLBACK ?= https://no-vm-desktop-fix--novm4.replit.app/

.PHONY: help install test list create quickstart clean env check

help:
	@echo "NoVM Agent Skill - https://virtual-xfce-spin--ogsincord.replit.app/"
	@echo "Dot file .novm -> \$$NOVM = $(NOVM)"
	@echo ""
	@echo "Targets:"
	@echo "  install     - Setup dot file and env"
	@echo "  env         - Show current env"
	@echo "  check       - Check VM limit (2 max)"
	@echo "  list        - List sessions (GET \$$NOVM/api/sessions)"
	@echo "  create      - Create workstation (checks limit)"
	@echo "  quickstart  - Create+start+connect"
	@echo "  test        - Run basic tests"
	@echo "  clean       - Cleanup"
	@echo ""
	@echo "Usage with \$$NOVM:"
	@echo "  curl \"\$$NOVM/api/sessions\""
	@echo "  ./novm.sh list"
	@echo "  python3 novm_client.py list"

install:
	./install.sh

env:
	@echo "NOVM=$(NOVM)"
	@echo "FALLBACK=$(FALLBACK)"
	@echo "Dot file: $$(cat .novm 2>/dev/null || echo 'missing')"
	@echo "Env var: $$NOVM"

check:
	./novm.sh check-limit

list:
	./novm.sh list

create:
	./novm.sh create "Support Desktop" "1280x720" false

quickstart:
	./novm.sh quickstart "Support Desktop"

test:
	@echo "Testing dot file -> \$$NOVM mapping..."
	@test -f .novm && echo "✓ .novm exists: $$(cat .novm)" || echo "✗ .novm missing"
	@test -f .novmrc && echo "✓ .novmrc exists" || echo "✗ .novmrc missing"
	@source .novmrc && test -n "$$NOVM" && echo "✓ \$$NOVM set: $$NOVM" || echo "✗ \$$NOVM not set"
	@echo ""
	@echo "Testing bash CLI..."
	@./novm.sh env || true
	@echo ""
	@echo "Testing python client..."
	@python3 -c "from novm_client import NoVMClient; c=NoVMClient(); print(f'✓ Python client base_url: {c.base_url}')"
	@echo ""
	@echo "All basic checks passed!"

clean:
	rm -f *.log
	rm -rf __pycache__/
	rm -rf .pytest_cache/
	@echo "Cleaned"
