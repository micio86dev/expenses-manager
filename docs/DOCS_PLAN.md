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
- [x] `gga run --pr-mode` per repo; fix every finding (no rule disabling). Done on each repo's feature branch (PR range `develop...HEAD`): root (README and credentials), frontend (RegisterView fix), backend (DemoSeeder note), all PASSED. On `develop` the PR range is empty, so `make review` checks nothing there; the review has to run on a branch.
- [x] Gates: Pint, Larastan, Pest, coverage >= 90; vue-tsc, ESLint, Prettier, Vitest coverage >= 90, build; shellcheck and shfmt; contract drift; `check-readme.sh`; E2E smoke. Last full run, after the Phase 7 changes: `./start.sh --test` (Pest 541 passed, none skipped, coverage gate 90%; Vitest 565 passed, coverage 98.61%), `pnpm build` (initial JS 99.38 kB gzip, budget 150 kB), `make contract-check`, `check-readme.sh`, `make test-scripts` (all passed), the mocked Playwright suite (90 passed), and the full-stack Playwright suite against the demo stack on `API_PORT=8100 WEB_PORT=5174` (1 passed: register, categorise, spend, review, sign out).
- [x] Final pass for leftover non-English text and dead docs. The repository's own text is English (the `it` translation files excepted); two PHP tests with Italian literals now use translation keys. Accepted exception: the Engram chunks already published (`96a23c5a`, `2e4de61b`) hold the author's Italian chat messages as recorded data. The author chose to keep them over rewriting the public history; the README's Engram section says so.
- [x] Merge into `develop`; pin in root. Every feature branch is merged; the root pins the released commits of `backend` and `frontend`.

## Phase 6: Docs resync (queued by the user after the refactor)
- [x] Update root README, component READMEs and AGENTS.md to the refactored code, including the public repositories and the rebuild-from-prompts section.
- [x] Run `check-readme.sh` after the last README edit (passes).
- [x] Clean-clone check again from the public repository: run on `main` (v0.2.0), with the Quick start ports and the full smoke, all green. The busy-port wording is on `develop` and reaches `main` with the next release.
- [x] Engram: `engram sync` and commit `.engram/` (chunk `7c5b6123`: 13 prompts, all the author's own; the four reappeared GGA reviewer prompts were deleted first, as agreed). Outdated observations are replaced: the remotes and release notes in the Git Flow decision, and the launcher port and env behaviour in the commands note (Engram `mem_update`, 2026-10-13).
- [x] `gga run --pr-mode` per repo, final gates, merge into `develop`. Each feature branch was reviewed in PR mode and merged; the frontend, backend and root gates above were re-run on the final `develop`.

## Phase 7: Hardening after the final review (2026-10-13)
- [x] Client validation for expenses and categories moved to zod, like auth (`src/domain/expense-form.ts`, `src/domain/categories.ts`), with the amount checked in the currency's minor units. Shared runner `runSchema` now throws for a failed rule that belongs to no field, and `FieldNotes` keys its messages by index.
- [x] Category palette exception recorded in the frontend `AGENTS.md`: the hex values are sent to the API and mirror the `--category-*` tokens, which `tests/tokens.test.ts` checks.
- [x] Launcher bug fixed: a re-run on other ports kept the old `APP_URL`, `VITE_API_BASE_URL` and CORS origin, so the SPA reported "Cannot reach the server". `start.sh` now re-points localhost URLs and appends the SPA origin; other values stay. Covered by `scripts/test-scripts.sh` (dev, production and dry-run cases) and by the full-stack suite.
- [x] Generated `.atl/` cache untracked in the frontend, ignored like the backend and root.

## Release
- `v0.2.0` released with `scripts/release.sh minor` in all three repositories, then `v0.2.1` with `scripts/release.sh patch`, which brings the CI fixes (pinned shfmt, `composer audit --locked`, the busy-port note, the E2E mock fix) to `main`. Both are pushed to GitHub with branches and tags. CI on `main` is green for root, backend and frontend at `v0.2.1`.
- `v0.2.2` (`scripts/release.sh patch`, 2026-10-13) brings the register-view preload and the demo credentials documentation to `main`. Pushed with tags; CI green on `main` for root, backend and frontend.
- `v0.2.3` (`scripts/release.sh patch`, 2026-10-13) brings the zod validation of expenses and categories, the runSchema and FieldNotes hardening, the launcher fix that re-points localhost URLs and CORS on re-run, the `.atl/` untracking, and this plan's Phase 7. Pushed with tags; CI on `main` green for backend and frontend at `v0.2.3`, root run completed successfully.

## Progress log
- Root writer (2026-10-12): phase 1 root tooling, phase 2 start.sh, phase 3 check-readme, README and AGENTS.md written; shellcheck, shfmt, check-readme and contract-check green. Gaps: no API docs UI in backend; prod compose has no web service; commits blocked by the .git/hooks/pre-commit gga hook (see report).
