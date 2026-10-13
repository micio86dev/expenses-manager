# Docs and Launch Tooling Plan

Source: `REFACTOR_BRIEF.md`. Resume from the first unchecked box after a context clear.
Branch per repo used for this work: `feature/docs-launch-tooling` (root, backend, frontend), merged into `develop`. Merge `--no-ff` into `develop`; root pins submodules last. No release.

## Phase 1: Tooling (Engram and Guardian Angel)
- [x] Engram: `.engram/config.json` with `project_name: expenses_manager` in root, backend, frontend. (verified in all three repositories)
- [x] Engram: save architecture, conventions, commands, ports, gotchas (no secrets) via `mem_save`; `engram sync` from root; commit `.engram/`; document sync and import in README.
- [x] GGA: `gga init` per repo; `.gga` with `PROVIDER=claude`, `RULES_FILE=AGENTS.md`, `STRICT_MODE=true`, `PR_BASE_BRANCH=develop`, file patterns and exclusions (generated and vendored files only). (verified in all three repositories)
- [x] GGA: `gga run` as the LAST step of each `.githooks/pre-commit`, skipped with a clear message when `gga` is missing. No `gga install`. (verified in all three repositories)
- [x] AGENTS.md per repo: concise, checkable "Review rules" section. (verified in all three repositories)
- [x] Make targets `review` (`gga run --pr-mode`), `memory-sync`; dormant CI job `gga run --ci`. (verified in all three repositories; dormant CI job in root.yml)

## Phase 2: Launch script and checks
- [x] `start.sh` at root: bash, `set -euo pipefail`, idempotent, `--help`, `--dry-run`, `--prod`, `--demo`, `--rebuild`, `--down`, `--reset` (confirmation), `--logs`, `--test`.
- [x] Checks: git, Docker daemon, Compose v2, free ports; submodule init; `.env` from `.env.example` with generated secrets (never overwrite).
- [x] Flow: build, start, wait on healthchecks, migrate, Reference seeders (Demo with `--demo`), print URLs and demo credentials.
- [x] shellcheck and shfmt clean.
- [x] `scripts/check-readme.sh` (README targets, flags and env vars must exist); CI step.

## Phase 3: Documentation
- [x] Root README (English, complete): overview, Mermaid architecture, stack and versions, repo layout and submodules, prerequisites, quick start, manual Docker guide, make and script reference, seeding, tests and coverage, OpenAPI workflow, i18n, performance, Git Flow and release, Engram and GGA, troubleshooting, conventions.
- [x] Component READMEs (backend, frontend) link to root and document their own commands. (Checked: every `make` target they name exists in their Makefile, except `make contract` and `make up`, which the text marks as superproject commands.)
- [x] Root AGENTS.md: stop saying the root README is Italian.

## Phase 4: Verify like a new user
- [x] Clean clone with `--recurse-submodules` from the public GitHub repository; `./start.sh --demo` run literally. Default ports 8000 and 5173 were busy on the test machine, so the launcher stopped with its fix message; the run passed with `API_PORT=8100 WEB_PORT=5174`, and the Quick start now names that fix.
- [x] Smoke on the clone: `/health`, `/ready`, SPA 200, register 201, login 200, category 201, expense 201, stats 200.
- [x] `./start.sh --test` on the clone (backend 540 passed, 1 skipped by design; frontend 560 passed); `./start.sh --down`; `./start.sh --prod --dry-run`.
- [x] Mismatch fixed: the busy-port note in the Quick start. It was merged after the clone run; its final wording is covered by `check-readme.sh` and by the PR-mode review of the `feature/quick-start-ports` branch (PASSED).

## Phase 5: Review and final gates
- [ ] `gga run --pr-mode` per repo; fix every finding (no rule disabling). Partial: PR-mode ran on the root and frontend feature branches (PASSED). On `develop` the PR range is empty, so `make review` checks nothing there. The backend's last changes were reviewed by the pre-commit hook, not by a PR-mode run.
- [ ] Gates: Pint, Larastan, Pest, coverage >= 90; vue-tsc, ESLint, Prettier, Vitest coverage >= 90, build; shellcheck and shfmt; contract drift; `check-readme.sh`; E2E smoke. Passed: all of them, with `./start.sh --test` (Pint, Larastan, Pest 540 passed with coverage gate 90%; vue-tsc, ESLint, Prettier, Vitest 560 passed, coverage 98.6%), `pnpm build`, shellcheck, shfmt, `make contract-check`, `check-readme.sh`, `test-scripts.sh`, and the mocked Playwright suite (90 passed). Not run: the full-stack Playwright suite (`e2e:fullstack`), which needs the running stack.
- [ ] Final pass for leftover non-English text and dead docs. Partial: the repository's own text is English (the `it` translation files excepted). Two PHP tests with Italian literals were rewritten to use translation keys. Not changed: the Engram chunks, which hold the author's Italian chat messages as data.
- [x] Merge into `develop`; pin in root. Every feature branch is merged; the root pins the released commits of `backend` and `frontend`.

## Phase 6: Docs resync (queued by the user after the refactor)
- [x] Update root README, component READMEs and AGENTS.md to the refactored code, including the public repositories and the rebuild-from-prompts section.
- [x] Run `check-readme.sh` after the last README edit (passes).
- [ ] Clean-clone check again: the last clone run happened before the busy-port wording was merged, so rerun it from the public repository.
- [ ] Engram: replace outdated observations, `engram sync`, commit `.engram/`. Not done: the sync needs a decision on the orchestration prompts still in the local memory.
- [ ] `gga run --pr-mode` per repo, final gates, merge into `develop`. Same partial status as phase 5.

## Release
- `v0.2.0` released with `scripts/release.sh minor` in all three repositories, pushed to GitHub with branches and tags. The release does not include the later README busy-port note and the E2E mock fix, which are on `develop`.

## Progress log
- Root writer (2026-10-12): phase 1 root tooling, phase 2 start.sh, phase 3 check-readme, README and AGENTS.md written; shellcheck, shfmt, check-readme and contract-check green. Gaps: no API docs UI in backend; prod compose has no web service; commits blocked by the .git/hooks/pre-commit gga hook (see report).
