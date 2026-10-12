# Expenses Manager — Delivery Plan

Source of truth for the brief: `BRIEF.md`. Approved plan: the planning session output, mirrored here.
Resume point after a context clear: find the first unchecked box and continue from it.

## Phases

- [ ] **Phase 1 — Root repo and skeleton**: superproject, submodules, Git Flow scripts, hooks, AGENTS.md, README, `.mcp.json`, OpenAPI contract, Docker/Makefile skeleton.
- [ ] **Phase 2 — Backend foundation**: Laravel 13 scaffold, strict tooling, Sanctum auth, ownership scope, i18n, migrations, seeders.
- [ ] **Phase 3 — Backend categories and expenses** (TDD, contract-validated).
- [ ] **Phase 4 — Backend stats, performance, caching**.
- [ ] **Phase 5 — Frontend foundation**: tooling, tokens, i18n, dates facade, typed API client, layouts/nav, auth.
- [ ] **Phase 6 — Frontend categories and expenses**.
- [ ] **Phase 7 — Dashboard and charts**.
- [ ] **Phase 8 — E2E, coverage ≥90%, Lighthouse, CI files, docs, release `0.1.0`, Engineering Report**.

## Definition of Done (every phase)

Tests pass · coverage ≥90% on the touched repo · Pint / PHPStan / ESLint / Prettier / vue-tsc clean · contract in sync · docs updated · no dead or duplicated code · clean tree before merge.

## Workflow

Per phase: `feature/<phase-slug>` → TDD (red / green / refactor) → gates green → Conventional Commits → `git merge --no-ff` into `develop`.

## Progress log

- Plan approved; repository bootstrap started.
