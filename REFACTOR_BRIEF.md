# ROLE
Senior full-stack/DevOps engineer. Finalize the "Expenses Manager" project documentation and launch tooling, then verify it end to end. Scope: root repo + `backend/` + `frontend/` submodules.
Chat with me in Italian. EVERYTHING written to disk is in ENGLISH only (README, docs, scripts, comments, commits). Italian only inside the `it` translation files. Be terse: no recaps, no large diffs in chat.
Project name is "Expenses Manager" (slug `expenses-manager`). Grep all three repos and fix any leftover "Spese"/"spese" in package names, compose project and container names, README titles, AGENTS.md, ADRs and the Engram project name. Italian user-facing strings in the `it` locale files are exempt.

# MODE
1. PLAN MODE FIRST: audit README vs the real codebase (read-only), output a gap list + phased plan. Wait for approval.
2. After approval write the plan to `docs/DOCS_PLAN.md` (checkboxes, resume from it after a context clear).
3. Branch `feature/docs-launch-tooling` in each repo (Git Flow), Conventional Commits (`docs:`, `chore:`, `feat:`), merge `--no-ff` into `develop`, root updates submodule pointers last. NO release unless I ask.
4. Verify tool commands against official docs or `--help`; never assume.

# 1. TOOLING: Engram (memory) + Guardian Angel (review)
Prerequisite check: `engram`, `gga`, `jq`, `curl`, `shellcheck`. If a binary is missing install via Homebrew (`brew install gentleman-programming/tap/engram`, `brew install gentleman-programming/tap/gga`) or report if brew is unavailable.
Engram:
- Run `engram doctor`. Confirm the Claude Code plugin/MCP is registered (`engram setup claude-code` if not; needs a Claude Code restart, ask me to restart if so).
- Create `.engram/config.json` with `"project_name": "expenses_manager"` in ALL THREE repos so root, backend and frontend share one memory project (nearest config per git root wins). Check with `mem_current_project`.
- Save to memory (via MCP `mem_save`, topic keys via `mem_suggest_topic_key`, `mem_session_summary` at the end): stack and versions, architecture and layer rules, shared list-query layer, Resource/Service conventions, contract workflow, Git Flow + release procedure, all commands/ports/URLs, launch script usage, i18n and testing conventions, gotchas found. NEVER store secrets, tokens or `.env` values.
- `engram sync` from the root, commit the resulting `.engram/` chunks. Check `engram sync --help` and the docs for the import counterpart; document both in the README.
Guardian Angel:
- In each repo: `gga init`, then edit `.gga`: `PROVIDER="claude"`, `RULES_FILE="AGENTS.md"`, `STRICT_MODE="true"`, `PR_BASE_BRANCH="develop"`, sensible `FILE_PATTERNS`/`EXCLUDE_PATTERNS` (backend: `*.php`, exclude `vendor/*`, migrations optional; frontend: `*.ts,*.vue`, exclude `*.d.ts`, the generated `src/api/schema.d.ts`, `dist/*`). Keep cache on.
- Hook conflict: we use `core.hooksPath=.githooks`, so `gga install` would write an ignored `.git/hooks/pre-commit`. Instead call `gga run` as the LAST step of `.githooks/pre-commit` (after lint/typecheck/tests). Do not use `gga install`. Skip cleanly with a clear message if `gga` is missing.
- Make `AGENTS.md` in each repo contain a concise, checkable "Review rules" section (strict types, thin controllers, logic in Services, Resources reuse via `whenLoaded`, no raw SQL, owner isolation, English-only, a11y, i18n keys, no dead code, tests for every change). GGA reviews staged files against it.
- Add `make review` (`gga run --pr-mode`), `make memory-sync`; add a dormant CI job running `gga run --ci`.

# 2. LAUNCH SCRIPT (`./start.sh` at the root)
Bash, `set -euo pipefail`, shellcheck + shfmt clean, idempotent, colored but plain-text safe, `--help`, `--dry-run`.
- Checks: git, Docker daemon, Compose v2, free ports.
- `git submodule update --init --recursive`; create `.env` files from `.env.example` if missing (generate `APP_KEY` and secrets, never overwrite existing values).
- Flags: `--prod`, `--demo` (also run Demo seeders; Reference seeders always), `--rebuild`, `--down`, `--reset` (drops volumes, requires explicit confirmation), `--logs`, `--test` (run the full suite in containers).
- Flow: build, start, wait on healthchecks (`/health`, `/ready`, frontend), run migrations + Reference seeders, print URLs, API docs link and demo credentials when `--demo`.
- Clear error messages with the fix for each failure. No `sudo`.
- Add `scripts/check-readme.sh` (and CI step): fails if the README references a `make` target, script flag or env var that does not exist.

# 3. README.md (root, English, complete)
Sections: overview and features; architecture (Mermaid: containers, layers, request flow); tech stack with versions; repo layout and submodules (and how to fetch/update them, `git submodule set-url` for when a remote exists); prerequisites; Quick start (`./start.sh`); manual Docker guide (dev and prod, ports, volumes, healthchecks, env vars table); Makefile and script reference; seeding (Reference vs Demo); running tests, coverage (>=90%), lint, typecheck, E2E, contract drift; OpenAPI workflow (`make contract`, generated frontend types, docs UI); i18n (add a language); performance notes (caching, indexes, budgets); Git Flow and release procedure (`scripts/gitflow.sh`, `scripts/release.sh patch|minor|major`, hotfix); Engram and Guardian Angel usage; troubleshooting; conventions (English-only, TDD, strict typing, definition of done). Each submodule README gets a short component-level guide linking to the root one.

# 4. VERIFY LIKE A NEW USER (docs-as-tests)
- Clone the root into a temp dir with `--recurse-submodules`, follow the README literally, run `./start.sh --demo`, then smoke-test: `/health`, `/ready`, frontend 200, register + login via API, create category + expense, stats endpoint, and `./start.sh --test`. Then `./start.sh --down` and test `--prod --dry-run`.
- Every command that fails or differs from the README is a bug: fix the README or the script, then rerun the whole flow.
- Check README claims against the code: ports, versions, env vars, make targets, folder names.

# 5. CODE REVIEW WITH GGA
- Before merging each repo: `gga run --pr-mode`. Fix every finding properly (no rule disabling, no pattern exclusions to dodge findings; exclusions only for generated or vendored files). Re-run until it passes.
- Then a final manual pass for leftover non-English text and dead docs.

# 6. FINAL GATES
Run once more everything touched by this work: backend (Pint, Larastan, Pest, coverage >= 90%), frontend (vue-tsc, ESLint, Prettier, Vitest coverage >= 90%, build), shellcheck/shfmt, `make contract` drift, `scripts/check-readme.sh`, E2E smoke. Never lower a threshold or skip a hook (`--no-verify` is forbidden).

# DEFINITION OF DONE
Fresh clone + `./start.sh --demo` yields a working app with no manual steps beyond Docker; README matches reality; Engram holds the project knowledge and `.engram/` is synced and committed; GGA passes on all repos and runs in the pre-commit hook; all gates green; clean trees merged into `develop`. End with a short report: what changed, what was verified, remaining risks.
