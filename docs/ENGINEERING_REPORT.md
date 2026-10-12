# Engineering Report: Expenses Manager 0.1.0

Status: first release. Scope: superproject, `backend/`, `frontend/`. Every number below comes from a gate run on the release tree.

## 1. Stack and versions

| Area | Component | Version |
| --- | --- | --- |
| Runtime | PHP | 8.5 (image `php:8.5-fpm-alpine`) |
| Backend | Laravel | 13.35 |
| Backend | Sanctum | 4.3 (personal access tokens) |
| Backend | Pest | 5.3 |
| Backend | Larastan (PHPStan) | 3.13, level max |
| Backend | spectator (OpenAPI 3.1 contract tests) | 3.0 |
| Frontend | Node.js | 24 |
| Frontend | Vue | 3.5 |
| Frontend | TypeScript | 6.0 (pinned by typescript-eslint) |
| Frontend | Vite | 8.3 |
| Frontend | Pinia / vue-router / vue-i18n | 4.0 / 5.4 / 11.4 |
| Frontend | Chart.js | 4.5 (lazy dashboard chunk) |
| Frontend | Vitest / Playwright | 5.0 / 1.64 |
| Data | SQLite (default), WAL journal, 5 s busy timeout | |
| Contract | OpenAPI | 3.1, `contracts/openapi.yaml` |

## 2. Architecture

- **API layers:** thin controllers, then FormRequests and API Resources, then Actions (one use case each), then repository interfaces with Eloquent implementations, then models.
- **Ownership:** every domain row has `owner_id`, enforced by one global scope. System categories are shared rows, visible through the explicit `IncludesUnownedRows` scope, and read-only through the API.
- **Money:** integer minor units with an ISO 4217 currency. Amounts are capped at 99,999,999,999 cents. Totals are never mixed across currencies.
- **Statistics:** SQL aggregates on the plain `spent_on` date, with week and month buckets computed in PHP. Results are cached per owner under a version token that every write bumps, with a strong ETag and 304 responses.
- **Frontend layers:** pages (thin route entries), views (feature compositions), presentational components, Pinia stores, a typed API client generated from the contract, and pure domain modules with no framework imports. The dayjs facade is the only file allowed to import dayjs.
- **Frontend data:** list fetches are keyed by serialized filters, and stale responses are ignored. Optimistic updates roll back per operation.

## 3. Verification

| Gate | Backend | Frontend |
| --- | --- | --- |
| Unit and feature tests | 541 passed | 532 passed (unit and component) |
| Coverage | 99.6 % (PCOV, threshold 90) | 98.6 % statements, 95.7 % branches, 97.7 % functions, 99.0 % lines (threshold 90) |
| Static analysis | PHPStan max, no errors, no ignores | vue-tsc, ESLint, Prettier clean |
| Architecture | Arch tests: strict types, final classes, layering, no Eloquent outside repositories | Lint rules ban `new Date` outside the dates facade |
| Contract | Every API route validated with spectator | Types regenerated from the contract (`make contract-check` clean) |
| Accessibility | Not applicable | axe in unit tests; Playwright axe on every page, light and dark, desktop and mobile |
| Browser E2E | Not applicable | Mocked suite 90 passed; full-stack journey passed 5/5 against the real stack |
| Lighthouse (mobile, production build) | Not applicable | Login: perf 98, a11y 100, best practices 100. Dashboard: perf 95–96, a11y 100, best practices 100 |
| Bundle budget | Not applicable | Initial JS 75.97 kB gzip (budget 150). Chart chunk 67.90 kB gzip, lazy |
| Dependency audit | `composer audit`: no advisories | `pnpm audit --prod`: no known vulnerabilities |

## 4. Defects found and fixed

- **Last day dropped from filters:** expenses were stored with a time component, so a range ending on a given day excluded it. Fixed by persisting `spent_on` as a calendar date. Covered by an API-level boundary test.
- **Statistics 500 on valid ranges:** the previous-period query re-ran the 5-year span guard. Fixed by applying the guard to the requested range only.
- **Integer overflow in daily average:** fixed with quotient and remainder arithmetic, and an amount cap at the request layer and in the contract.
- **Login throttle bypass:** the email key was not normalized the same way as the request. Fixed with one shared helper, plus an IP-only limit.
- **Non-expiring tokens:** tokens now expire after 30 days by default, with a daily prune.
- **Untrusted proxies:** trusted proxies are configured from `TRUSTED_PROXIES`, defaulting to none.
- **Unrestricted CORS:** origins come from `CORS_ALLOWED_ORIGINS`, and the ETag header is exposed for revalidation.
- **SQLite lock errors under parallel requests:** the dashboard issued parallel requests and the database cache returned "database is locked". Fixed with a 5 s busy timeout and WAL journaling.
- **Nginx 502 after the PHP container is recreated:** nginx resolved the upstream once at startup. Fixed by resolving `php` through Docker DNS per request.
- **Dev volume ownership:** the SQLite volume was created as root, so PHP could not write. Fixed in the dev image; artisan commands in dev must run as `www-data`.
- **Dev server start:** the dev container failed when started through `pnpm exec`. It now starts Vite directly.

## 5. Known limits and risks

- **Stats cache is never pruned.** Keys become unreachable after each write, so the database cache table grows. Follow-up: a scheduled prune.
- **Wildcards in search:** `%` and `_` in `q` are not escaped, so `q=%` matches everything. It is bound safely, not an injection, but it is a correctness issue.
- **Duplicate category race:** validation is check-then-insert. Concurrent duplicates hit the unique index and return 500. Follow-up: map the unique violation to 422.
- **Account enumeration on registration:** the unique-email rule reveals whether an email exists. Inherent to the contract; limited to 10 registrations per minute per IP.
- **Token storage:** the SPA keeps the access token in `localStorage`. A script running on the page could read it, so XSS prevention is the main control.
- **TypeScript pinned to 6.0.x** until typescript-eslint supports a newer release.
- **CI is dormant:** the workflows have never run on GitHub because there is no remote.
- **Dashboard top-expenses E2E** runs against a mocked endpoint in the mocked suite; the full-stack journey does not cover it.

## 6. Release

`0.1.0` is the first release of the superproject, `backend/` and `frontend/`, created with `scripts/release.sh`. Each repository gets an annotated `v0.1.0` tag on `main`. Release notes are in each `CHANGELOG.md`.
