# ROLE
Senior full-stack engineer. Build "Expenses manager", a personal-expense tracker + admin panel, from scratch in the CURRENT folder.
Chat with me in Italian. EVERYTHING written to disk is in ENGLISH only: code, comments, docs (README, AGENTS.md, ADRs, CHANGELOG, docs/PLAN.md), commit messages, branch names, test names, OpenAPI. The only Italian allowed is the `it` translation resource files (user-facing strings).

# MODE
1. PLAN MODE FIRST: read this whole brief, output a phased plan (checklist, files, commands, risks). Write nothing. Wait for approval.
2. After approval: write the plan to `docs/PLAN.md` (checkbox per phase). Tick boxes as you go; if context is cleared, resume from it.
3. Per phase: `feature/*` branch -> TDD (red/green/refactor) -> all gates green -> Conventional Commits -> merge `--no-ff` into `develop`. If blocked, stop and report. Never skip a gate or lower a threshold.
4. Verify library versions/APIs with Context7 or docs; never assume (Laravel 13, Vite, Vitest, Pinia, vue-i18n are recent).

# REPOS & GIT FLOW
- Root (current folder) = superproject repo. `backend/` and `frontend/` = separate repos added as submodules (local paths). NO remote exists: never add/push remotes; document `git submodule set-url` for later.
- All 3 repos: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`.
- `scripts/gitflow.sh` (feature|hotfix start/finish) and `scripts/release.sh <patch|minor|major>`: read last `vX.Y.Z` tag (none -> first release `0.1.0`), bump, `release/x.y.z` from develop, update VERSION+CHANGELOG, merge to main + annotated tag, back-merge to develop; backend, frontend, then root (updating submodule pointers). Hotfix = from main, patch bump. Refuse dirty trees.
- `.githooks/` (set via `make setup`): pre-commit (lint, typecheck, related tests), commit-msg (conventional).

# CONTRACT (source of truth)
- `contracts/openapi.yaml` (3.1) in root. `make contract` copies it into both repos; CI fails on drift.
- Backend feature tests validate every response against it (hotmeteor/spectator). Frontend types generated with openapi-typescript. Serve spec + Scalar UI only in non-prod.
- REST under `/api/v1`, errors RFC 9457 Problem Details (localized). Money = integer minor units + ISO currency. UUID PKs.
- Endpoints: auth (register/login/logout/me), expenses (CRUD; filters from/to/category_id/q; paginated), categories (CRUD), stats: summary (total, count, daily avg, delta vs previous period, top category, biggest expense), by-category, timeseries (granularity day|week|month); all take from/to.

# BACKEND (Laravel 13)
- `declare(strict_types=1)` everywhere, `final` by default, readonly DTOs, PHP enums, full typing. Larastan max level, Pint, `Model::shouldBeStrict()`.
- SOLID/OOP layers: thin Controllers + FormRequests + API Resources -> Actions (one use case per class) -> Repository interfaces (Eloquent impls bound in a provider) -> Models. Value objects: `Money`, `DateRange`. `Period` enum resolved by `PeriodResolver` (strategy per period). No duplicated query/filter logic: reusable filter objects/scopes.
- Auth: Sanctum personal tokens, throttled.
- Multi-tenant-ready: every domain table has `owner_id`; one `OwnedByCurrentOwner` trait + global scope + `CurrentOwner` contract (user today, tenant tomorrow = one binding change).
- DB-agnostic: SQLite default via .env only. Eloquent/Query Builder only; no raw SQL or dialect functions; no JSON-column queries. Aggregate in SQL on plain `spent_on` (SUM/COUNT/GROUP BY), bucket week/month in PHP.
- Migrations = schema only. Seeders separated: `Seeders/Reference/` (idempotent system categories keyed by translation key, safe in prod) and `Seeders/Demo/` (factories, local only). `DatabaseSeeder` runs Reference always, Demo only in `local`.
- Categories: name, color, icon (small fixed set), unique per owner; system ones read-only; archive instead of delete when in use.
- i18n: `lang/it`, `lang/en` (validation, errors, system category names). `SetLocale` middleware from `Accept-Language` against `config/locales.php` allowlist; user locale preference stored. New language = one folder + one config line.
- Performance: indexes `(owner_id, spent_on)` and `(owner_id, category_id, spent_on)`; select needed columns; eager loading; `preventLazyLoading` outside prod; query-count assertions in tests; stats cached per owner with version-key invalidation on writes (works on any cache driver); ETag on stats GET; prod image with config/route/event/view cache + OPcache; rate limits; `/health` + `/ready`; JSON logs with request-id.
- Tests (Pest, TDD): unit (value objects, resolvers, actions with fakes), feature (all endpoints, auth, owner isolation, i18n, contract), arch tests (strict types, thin controllers, no Eloquent outside repositories). PCOV, `--min=90`.

# FRONTEND (Vue 3 + TS strict)
- Vite, pnpm, `<script setup lang="ts">`, tsconfig `strict` + `noUncheckedIndexedAccess` + `exactOptionalPropertyTypes`, Pinia, vue-router (lazy routes), vue-i18n with typed keys, Vitest + @vue/test-utils + happy-dom, Playwright, ESLint (typescript-eslint strict + vue + vuejs-accessibility), Prettier.
- Structure: `src/components/{atoms,molecules,organisms}`, `views` (feature compositions), `pages` (thin route entries), `layouts`, `composables`, `stores`, `api` (typed client + snake->camel mappers), `domain` (pure TS), `i18n`, `lib/dates.ts`, `styles`. Props down, events up; no business logic in components.
- Dates: dayjs ONLY, behind `src/lib/dates.ts` (isoWeek, customParseFormat, locale lazy-loaded with i18n locale). ESLint bans `new Date`/`Date.` elsewhere. Periods: day, week (ISO, Mon start), month, custom past range (from <= to <= today); prev/next navigation; period lives in URL query.
- i18n: it default + en; lazy locale chunks; persisted (localStorage + user setting); `<html lang>` and dayjs locale synced; `Intl` for numbers/currency; switcher in settings; unit test enforcing identical key sets. New language = one file + one registry line.
- Pages: Login/Register, Dashboard, Expenses (grouped by day with day totals; filter sheet: period/category/text; "load more"; add/edit in bottom sheet), Categories (CRUD, color/icon, archive), Settings (language, logout).
- Dashboard: period selector + prev/next; KPI strip (total, % vs previous period, daily average, count); charts: spend over time (bars), category breakdown (doughnut + ranked list with %), current vs previous period (line), top 5 expenses. Chart.js + vue-chartjs, tree-shaken, lazy route; text alternative for each chart; color never the only signal.
- Mobile-first: bottom tab bar on mobile, sidebar from 52rem; FAB "Add expense" -> bottom sheet, amount first (`inputmode=decimal`), recent categories as chips; targets >=44px; safe-area insets; skeleton loaders; optimistic updates with rollback; clear error/empty/offline states; `prefers-reduced-motion`; dark theme via `prefers-color-scheme`; WCAG 2.2 AA.
- Design (load `frontend-design` skill): cold mineral palette (salt #F2F5F4, mist #E3EAE8, basalt #1B2427, ocean #0B6B72, brick #A32A3A), one self-hosted variable family (Schibsted Grotesk) with tabular numerals, ledger-style ruled rows instead of identical cards, large amount input as the signature element, sentence-case plain copy, no all-caps eyebrows. Tokens as CSS variables.
- Performance: route code-splitting, lazy charts, `font-display: swap`, no heavy UI kits, virtualize lists only if measured >200 rows, debounced search. Budgets: initial JS <=150 kB gzip, Lighthouse mobile >=90 (perf/a11y/best-practices).
- Tests: unit for components, stores, composables, api, domain, dates, i18n; thresholds 90% lines/functions/statements/branches. Playwright E2E: (a) fast suite with mocked API, desktop + mobile viewports, axe checks; (b) full-stack suite against docker compose (register -> add category -> add expense -> dashboard updates -> date-range filters).

# DEVOPS
- Docker: `docker-compose.yml` (dev: php-fpm+nginx, vite, healthchecks, volumes, sqlite file in a volume), `docker-compose.prod.yml`, multi-stage Dockerfiles (dev / test with PCOV / prod), non-root, pinned versions, `.dockerignore`.
- `Makefile`: setup up down logs test coverage lint typecheck e2e contract release.
- GitHub Actions committed but dormant: backend (pint, phpstan, pest coverage min 90, composer audit), frontend (typecheck, lint, vitest coverage, build, pnpm audit), contract drift, e2e, docker build. Dependabot config.
- `.env.example` per repo, no secrets in git. CORS/security headers via env.
- `AGENTS.md` in root and each repo (stack rules, commands, architecture map, definition of done); `CLAUDE.md` = `@AGENTS.md`. Root README in Italian.

# SKILLS & MCP
- Install skill: copy `skills/engineering-excellence/` from https://github.com/micio86dev/Engineering-Excellence into `.claude/skills/engineering-excellence/`. Follow it (SDD -> TDD, quality gates, final Engineering Report). Also use `frontend-design`.
- Project `.mcp.json`: context7, playwright, laravel-boost (`laravel/boost`, `php artisan boost:install`). Verify each works; skip and report if not. No servers needing remote credentials.

# PHASES
1. Root repo, submodules, Git Flow scripts, hooks, AGENTS.md, skills/MCP, OpenAPI contract, Docker/Makefile skeleton.
2. Backend foundation: scaffold, strict tooling, auth, ownership, i18n, migrations + seeders.
3. Backend categories + expenses (TDD).
4. Backend stats + performance + caching.
5. Frontend foundation: tooling, tokens, i18n, dates facade, api client, layouts/nav, auth.
6. Frontend categories + expenses.
7. Dashboard + charts.
8. E2E, coverage >=90%, Lighthouse, CI files, docs. Release `0.1.0` via `scripts/release.sh`, then the Engineering Report.

# DEFINITION OF DONE (every phase)
Tests pass; coverage >=90% on touched repo; Pint/PHPStan/ESLint/Prettier/vue-tsc clean; contract in sync; docs updated; no dead or duplicated code; clean tree before merge.
