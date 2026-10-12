# Expenses Manager

Tracker personale delle spese con pannello di amministrazione.

Il progetto è un superprogetto Git con due sottomoduli:

- `backend/` — API REST in Laravel 13 (PHP), con Sanctum, Pest e PHPStan.
- `frontend/` — SPA in Vue 3 + TypeScript strict, con Pinia, vue-i18n e Chart.js.

Il contratto HTTP è in `contracts/openapi.yaml` ed è la fonte di verità per backend e frontend.
Le regole per chi lavora sul codice sono in `AGENTS.md`.

## Requisiti

- Docker con Compose
- PHP 8.5 e Composer (per lavorare fuori dal container)
- Node.js 24 e pnpm

## Avvio rapido

```bash
git clone --recurse-submodules <url> expenses_manager
cd expenses_manager
make setup      # attiva .githooks e installa le dipendenze
make up         # avvia API (http://localhost:8000), SPA (http://localhost:5173)
```

## Comandi principali

| Comando | Cosa fa |
| --- | --- |
| `make test` | Test backend e frontend |
| `make coverage` | Test con soglia di copertura ≥90% |
| `make lint` | Pint, ESLint, Prettier |
| `make typecheck` | PHPStan e vue-tsc |
| `make e2e` | Suite Playwright |
| `make contract` | Copia `contracts/openapi.yaml` in backend e frontend |
| `make contract-check` | Fallisce se le copie sono fuori sincrono |
| `make release BUMP=patch` | Rilascia tutti i repository (`scripts/release.sh`) |

## Flusso Git

Ogni repository usa Git Flow: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*`.

- Avvio e chiusura di feature o hotfix: `scripts/gitflow.sh`.
- Release: `scripts/release.sh <patch|minor|major>`, che aggiorna `VERSION` e `CHANGELOG.md`
  in ogni repository, crea il tag annotato e poi aggiorna i puntatori dei sottomoduli nel superprogetto.
- I commit seguono Conventional Commits (verificato da `.githooks/commit-msg`).

Il progetto non ha remoti configurati. Per collegare un remoto più avanti:

```bash
git submodule set-url backend <url-backend>
git submodule set-url frontend <url-frontend>
git remote add origin <url-superprogetto>
```

## Lingua

Tutto ciò che è scritto su disco è in inglese (codice, commenti, documentazione, commit, test).
Fanno eccezione questo README e i file di traduzione `it` dell'interfaccia.
