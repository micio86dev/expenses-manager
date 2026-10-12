SHELL := /bin/bash
.DEFAULT_GOAL := help

CONTRACT := contracts/openapi.yaml
CONTRACT_COPIES := backend/contracts/openapi.yaml frontend/contracts/openapi.yaml
BUMP ?= patch

.PHONY: help setup up down logs test coverage lint typecheck e2e contract contract-check release

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Activate git hooks and install dependencies
	git config core.hooksPath .githooks
	$(MAKE) -C backend setup
	$(MAKE) -C frontend setup

up: ## Start the dev stack
	docker compose up -d --wait

down: ## Stop the dev stack
	docker compose down

logs: ## Follow dev stack logs
	docker compose logs -f

test: ## Run backend and frontend tests
	$(MAKE) -C backend test
	$(MAKE) -C frontend test

coverage: ## Run tests with coverage gates (>=90%)
	$(MAKE) -C backend coverage
	$(MAKE) -C frontend coverage

lint: ## Run Pint, ESLint and Prettier checks
	$(MAKE) -C backend lint
	$(MAKE) -C frontend lint

typecheck: ## Run PHPStan and vue-tsc
	$(MAKE) -C backend typecheck
	$(MAKE) -C frontend typecheck

e2e: ## Run Playwright suites
	$(MAKE) -C frontend e2e

contract: ## Copy the OpenAPI contract into backend and frontend
	@for target in $(CONTRACT_COPIES); do mkdir -p $$(dirname $$target) && cp $(CONTRACT) $$target; done
	@echo "Contract copied to: $(CONTRACT_COPIES)"

contract-check: ## Fail when the contract copies drift from the source of truth
	@for target in $(CONTRACT_COPIES); do \
		diff -q $(CONTRACT) $$target >/dev/null || { echo "Contract drift: $$target"; exit 1; }; \
	done
	@echo "Contract copies are in sync"

release: ## Release all repositories (BUMP=patch|minor|major)
	scripts/release.sh $(BUMP)
