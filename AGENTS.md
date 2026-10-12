# AGENTS.md — Expenses Manager

Personal expense tracker with an admin panel. Superproject with two submodules:
`backend/` (Laravel 13, PHP) and `frontend/` (Vue 3 + TypeScript strict). The contract in
`contracts/openapi.yaml` is the source of truth for the HTTP API.

## Language rules

- Everything written to disk is English: code, comments, docs, commit messages, branch names,
  test names, OpenAPI. The only Italian allowed is the `it` translation resource files.
- The root `README.md` is the one exception: it is written in Italian.

## Workflow

- Git Flow in every repository: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`.
- Per phase: `feature/<phase-slug>` → TDD (red, green, refactor) → all gates green →
  Conventional Commits → `git merge --no-ff` into `develop`.
- Never add remotes. Never skip a gate or lower a threshold.
- Use `scripts/gitflow.sh` for feature and hotfix start/finish, `scripts/release.sh` for releases.
- Commit messages follow Conventional Commits. No AI attribution lines.

## Commands

| Command | Purpose |
| --- | --- |
| `make setup` | Install dependencies and activate `.githooks` |
| `make up` / `make down` | Start or stop the dev stack |
| `make test` | Backend and frontend unit/feature tests |
| `make coverage` | Tests with coverage gates (≥90%) |
| `make lint` | Pint, ESLint, Prettier |
| `make typecheck` | PHPStan (max), vue-tsc |
| `make e2e` | Playwright suites |
| `make contract` | Copy `contracts/openapi.yaml` into `backend/` and `frontend/` |
| `make release BUMP=patch\|minor\|major` | Run `scripts/release.sh` |

## Architecture map

### Backend (`backend/`)

- `app/Http/Controllers` — thin; delegate to Actions.
- `app/Http/Requests` — validation (FormRequests).
- `app/Http/Resources` — API Resources (output shape).
- `app/Actions` — one use case per class.
- `app/Repositories` — interfaces; Eloquent implementations bound in a provider.
- `app/Models` — Eloquent models, `OwnedByCurrentOwner` trait and global scope.
- `app/Support/ValueObjects` — `Money`, `DateRange`.
- `app/Support/Periods` — `Period` enum and `PeriodResolver` strategies.

Rules:
- `declare(strict_types=1)` everywhere; classes are `final` by default; DTOs are `readonly`.
- Eloquent and Query Builder only. No raw SQL, no dialect functions, no JSON-column queries.
- Money is integer minor units plus ISO currency. IDs are UUIDs.
- Every domain table has `owner_id`. Owner isolation is enforced by the global scope.
- Migrations hold schema only. Seeders live in `Database/Seeders/Reference` (always) and
  `Database/Seeders/Demo` (local only).

### Frontend (`frontend/`)

- `src/pages` — thin route entries.
- `src/views` — feature compositions.
- `src/components/{atoms,molecules,organisms}` — presentational; props down, events up.
- `src/composables`, `src/stores` — state and behavior; no business logic in components.
- `src/api` — typed client, generated types, snake-to-camel mappers.
- `src/domain` — pure TypeScript.
- `src/lib/dates.ts` — the only place allowed to use dayjs (`new Date` and `Date.` are banned).
- `src/i18n` — vue-i18n with typed keys; `it` default, `en`.

## Definition of done

Tests pass · coverage ≥90% on the touched repo · Pint, PHPStan, ESLint, Prettier, vue-tsc clean ·
contract in sync · docs updated · no dead or duplicated code · clean tree before merge.

## Progress

`docs/PLAN.md` is the progress document. Tick boxes only after the gates have actually passed.
