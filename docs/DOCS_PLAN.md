# Docs and Launch Tooling Plan

Source: `REFACTOR_BRIEF.md`. Resume from the first unchecked box after a context clear.
Branch per repo: `feature/docs-launch-tooling` (root, backend, frontend). Merge `--no-ff` into `develop`; root pins submodules last. No release.

## Phase 1: Tooling (Engram and Guardian Angel)
- [ ] Engram: `.engram/config.json` with `project_name: expenses_manager` in root, backend, frontend.
- [ ] Engram: save architecture, conventions, commands, ports, gotchas (no secrets) via `mem_save`; `engram sync` from root; commit `.engram/`; document sync and import in README.
- [ ] GGA: `gga init` per repo; `.gga` with `PROVIDER=claude`, `RULES_FILE=AGENTS.md`, `STRICT_MODE=true`, `PR_BASE_BRANCH=develop`, file patterns and exclusions (generated and vendored files only).
- [ ] GGA: `gga run` as the LAST step of each `.githooks/pre-commit`, skipped with a clear message when `gga` is missing. No `gga install`.
- [ ] AGENTS.md per repo: concise, checkable "Review rules" section.
- [ ] Make targets `review` (`gga run --pr-mode`), `memory-sync`; dormant CI job `gga run --ci`.

## Phase 2: Launch script and checks
- [ ] `start.sh` at root: bash, `set -euo pipefail`, idempotent, `--help`, `--dry-run`, `--prod`, `--demo`, `--rebuild`, `--down`, `--reset` (confirmation), `--logs`, `--test`.
- [ ] Checks: git, Docker daemon, Compose v2, free ports; submodule init; `.env` from `.env.example` with generated secrets (never overwrite).
- [ ] Flow: build, start, wait on healthchecks, migrate, Reference seeders (Demo with `--demo`), print URLs and demo credentials.
- [ ] shellcheck and shfmt clean.
- [ ] `scripts/check-readme.sh` (README targets, flags and env vars must exist); CI step.

## Phase 3: Documentation
- [ ] Root README (English, complete): overview, Mermaid architecture, stack and versions, repo layout and submodules, prerequisites, quick start, manual Docker guide, make and script reference, seeding, tests and coverage, OpenAPI workflow, i18n, performance, Git Flow and release, Engram and GGA, troubleshooting, conventions.
- [ ] Component READMEs (backend, frontend) link to root and document their own commands.
- [ ] Root AGENTS.md: stop saying the root README is Italian.

## Phase 4: Verify like a new user
- [ ] Clean clone with `--recurse-submodules`; follow the README literally; `./start.sh --demo`.
- [ ] Smoke: `/health`, `/ready`, frontend 200, register, login, category, expense, stats.
- [ ] `./start.sh --test`; `./start.sh --down`; `./start.sh --prod --dry-run`.
- [ ] Every mismatch fixed in README or script, then the whole flow rerun.

## Phase 5: Review and final gates
- [ ] `gga run --pr-mode` per repo; fix every finding (no rule disabling).
- [ ] Gates: Pint, Larastan, Pest, coverage >= 90; vue-tsc, ESLint, Prettier, Vitest coverage >= 90, build; shellcheck and shfmt; contract drift; `check-readme.sh`; E2E smoke.
- [ ] Final pass for leftover non-English text and dead docs.
- [ ] Merge into `develop`; pin in root.

## Phase 6: Docs resync (queued by the user after the refactor)
- [ ] Update root README, component READMEs and AGENTS.md to the refactored code.
- [ ] Run `check-readme.sh`, then the clean-clone check again.
- [ ] Engram: replace outdated observations, `engram sync`, commit `.engram/`.
- [ ] `gga run --pr-mode` per repo, final gates, merge into `develop`.

## Progress log
