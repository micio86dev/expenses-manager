# Expenses Manager — Delivery Plan

Source of truth for the brief: `BRIEF.md`. Approved plan: the planning session output, mirrored here.
Resume point after a context clear: find the first unchecked box and continue from it.

## Phases

- [x] **Phase 1 — Root repo and skeleton**: superproject, submodules, Git Flow scripts, hooks, AGENTS.md, README, `.mcp.json`, OpenAPI contract, Docker/Makefile skeleton.
- [x] **Phase 2 — Backend foundation**: Laravel 13 scaffold, strict tooling, Sanctum auth, ownership scope, i18n, migrations, seeders.
- [x] **Phase 3 — Backend categories and expenses** (TDD, contract-validated).
- [x] **Phase 4 — Backend stats, performance, caching**.
- [x] **Phase 5 — Frontend foundation**: tooling, tokens, i18n, dates facade, typed API client, layouts/nav, auth.
- [ ] **Phase 6 — Frontend categories and expenses**.
- [ ] **Phase 7 — Dashboard and charts**.
- [ ] **Phase 8 — E2E, coverage ≥90%, Lighthouse, CI files, docs, release `0.1.0`, Engineering Report**.

## Definition of Done (every phase)

Tests pass · coverage ≥90% on the touched repo · Pint / PHPStan / ESLint / Prettier / vue-tsc clean · contract in sync · docs updated · no dead or duplicated code · clean tree before merge.

## Workflow

Per phase: `feature/<phase-slug>` → TDD (red / green / refactor) → gates green → Conventional Commits → `git merge --no-ff` into `develop`.

## Progress log

- Plan approved; repository bootstrap started.
- Phase 1 (2026-10-12): superproject with `backend/` and `frontend/` submodules on `main` and `develop`; Git Flow and release scripts verified in a scratch superproject (first release 0.1.0, patch bump, changelog, submodule pins); hooks; Makefile; compose stacks; `.mcp.json`; OpenAPI contract extended and lint-clean (3 accepted warnings: localhost dev URLs); Engineering-Excellence skill copied.
- Known gaps carried forward: `backend/` and `frontend/` have no Makefile, Dockerfiles, or code yet (phases 2 and 5); `.mcp.json` servers are not verified as running (laravel-boost needs phase 2).
- Phase 2 (2026-10-12): backend foundation merged to backend `develop` (13 commits): Laravel 13 scaffold, Sanctum auth, ownership scope, i18n, RFC 9457 errors, health/ready, request-id JSON logs, seeders, arch and OpenAPI contract tests, multi-stage Docker. Gates re-run by the orchestrator: 143 tests pass, PHPStan max no errors, Pint passed, coverage 100% (PCOV).
- Note: the superproject pin for backend was committed directly on `develop` (not via a feature branch) because the dirty submodule blocked `feature start`.
- Phase 3 (2026-10-12): categories (system reference rows shared via explicit `IncludesUnownedRows` scope, custom CRUD, archive/unarchive) and expenses (CRUD, filters, pagination, constant-query listing) merged to backend `develop`. Gates re-run by the orchestrator: 309 tests pass, coverage 100% (PCOV), PHPStan max no errors, Pint passed. Contract gained 403 on archive/unarchive (system categories are read-only).
- Known open items: frontend still unscaffolded (phase 5); the GGA hook ignores PHP files.
- Phase 4 (2026-10-12): stats summary, by-category, timeseries (currency-isolated, gap-filled buckets), owner-scoped versioned cache, strong ETag with 304, per-user rate limit. Gates re-run by the orchestrator: 483 tests pass, coverage 99.5% (PCOV), PHPStan max no errors, Pint passed. Contract gained 429 on stats operations.
- Documented exception: one `selectRaw` for grouped SUM/COUNT in the stats repository (standard SQL, no dialect functions).
- Review (2026-10-12): backend read-only review; verified defects fixed on `develop` (spent_on stored as date, previous-period span, amount cap, login throttle keys and IP limit, token expiry and pruning, trusted proxies, Accept-Language vary). Reviewer's health-route drift claim was checked and rejected: the contract matches the code.
- Phase 5 (2026-10-12): frontend foundation merged to frontend `develop` (14 commits): pnpm tooling, tokens and self-hosted font, dayjs facade, typed i18n with lazy locales, typed API client with problem details, auth stores and guards, responsive shell, Playwright smoke, Docker dev/prod. Gates re-run by the orchestrator: typecheck and lint clean, 147 tests pass, coverage 99.5/98.2/99.2/99.7, Playwright 6/6 passed (per writer).
- Known limits: TypeScript pinned to 6.0.x (typescript-eslint constraint); token in localStorage (documented trade-off); no Lighthouse run yet.
- Phase 5 follow-up (2026-10-12): full dev stack verified end-to-end (health, ready, register, login, me, categories, stats). Fixed on `develop`: dev sqlite volume owned by www-data (migrations must run as `www-data`); API host port configurable with `API_PORT`; `make setup` in backend and frontend activates `.githooks`. Still open: the `frontend-design` skill is not installed in this environment, so design guidance came from the brief; Lighthouse not yet run (phase 8).
