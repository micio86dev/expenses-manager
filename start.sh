#!/usr/bin/env bash
# Expenses Manager launcher: builds, starts, migrates and seeds the Docker stack.
# Run ./start.sh --help for the options. Safe to run repeatedly (idempotent).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

DEV_API_PORT=8000
PROD_API_PORT=8080
DEFAULT_WEB_PORT=5173
WAIT_SECONDS=180
# Public sample credentials created by the Demo seeder (backend/database/seeders/Demo/DemoSeeder.php).
# Printed after a --demo start. Must match DemoSeeder::EMAIL and DemoSeeder::PASSWORD in the backend.
DEMO_EMAIL="demo@example.com"
DEMO_PASSWORD="demo-password"
REFERENCE_SEEDER='Database\Seeders\Reference\ReferenceSeeder'
DEMO_SEEDER='Database\Seeders\Demo\DemoSeeder'

PROD=0
DEMO=0
REBUILD=0
DOWN=0
RESET=0
LOGS=0
TEST=0
DRY_RUN=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_BOLD=$'\033[1m'
    C_OFF=$'\033[0m'
else
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_BOLD=""
    C_OFF=""
fi

info() { printf '%s==>%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
ok() { printf '%s ok%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: ./start.sh [options]

Builds, starts, migrates and seeds the Expenses Manager Docker stack.
Reference data is always seeded; the demo user and sample expenses only with --demo.

Options:
  --demo       Also run the Demo seeders (development stack only)
  --prod       Use docker-compose.prod.yml (API only, immutable images)
  --rebuild    Rebuild the images without the build cache
  --down       Stop the stack and exit (volumes are kept)
  --reset      Delete the stack volumes (SQLite data) after a typed confirmation, then start fresh
  --logs       Follow the stack logs; on its own it does not start anything
  --test       Run the full test suites in containers and exit (stack not started)
  --dry-run    Print what would run without changing anything
  -h, --help   Show this help

Environment:
  API_PORT     Host port of the API (default 8000, 8080 with --prod)
  WEB_PORT     Host port of the SPA (default 5173, development stack only)
  NO_COLOR     Disable colours

Examples:
  ./start.sh --demo
  API_PORT=8100 WEB_PORT=5174 ./start.sh --demo
  ./start.sh --prod --dry-run
EOF
}

# Prints an error and its fix, then exits. Dry runs only warn so every problem is listed.
problem() {
    local message="$1" fix="$2"
    if ((DRY_RUN)); then
        warn "$message (dry run: would stop here). Fix: $fix"
        return 0
    fi
    printf '%serror%s %s\n      Fix: %s\n' "$C_RED" "$C_OFF" "$message" "$fix" >&2
    exit 1
}

# Runs a command, or only prints it under --dry-run.
run() {
    if ((DRY_RUN)); then
        printf '  + %s\n' "$*"
        return 0
    fi
    "$@"
}

parse_args() {
    while (($#)); do
        case "$1" in
            --prod) PROD=1 ;;
            --demo) DEMO=1 ;;
            --rebuild) REBUILD=1 ;;
            --down) DOWN=1 ;;
            --reset) RESET=1 ;;
            --logs) LOGS=1 ;;
            --test) TEST=1 ;;
            --dry-run) DRY_RUN=1 ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                printf 'Unknown option: %s\n\n' "$1" >&2
                usage >&2
                exit 2
                ;;
        esac
        shift
    done

    if ((PROD && DEMO)); then
        printf 'error --demo and --prod cannot be combined: demo data is for development only.\n      Fix: drop one of the two flags.\n' >&2
        exit 2
    fi
}

docker_ready() {
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

check_prerequisites() {
    info "Checking prerequisites"
    command -v git >/dev/null 2>&1 || problem "git is not installed." "install git (https://git-scm.com/downloads)."
    command -v curl >/dev/null 2>&1 || problem "curl is not installed." "install curl; the script uses it for health checks."
    if ! command -v docker >/dev/null 2>&1; then
        problem "docker is not installed." "install Docker Desktop or Docker Engine (https://docs.docker.com/get-docker/)."
        return 0
    fi
    docker info >/dev/null 2>&1 || problem "the Docker daemon is not reachable." "start Docker Desktop (or the docker service) and run the script again."
    docker compose version >/dev/null 2>&1 || problem "Docker Compose v2 is missing ('docker compose')." "install the Compose plugin (https://docs.docker.com/compose/install/)."
    ok "git, curl, Docker daemon and Compose v2"
}

init_submodules() {
    info "Checking submodules"
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        warn "not a git checkout; skipping submodule initialisation"
        return 0
    fi
    # Only uninitialised submodules (status prefix "-") are updated, so local work on a
    # checked-out submodule branch is never reset to the commit recorded in the superproject.
    local pending
    pending="$(git submodule status --recursive | awk '/^-/ { print $2 }')"
    if [[ -z "$pending" ]]; then
        ok "submodules already initialised"
        return 0
    fi
    local path
    while IFS= read -r path; do
        run git submodule update --init --recursive -- "$path"
    done <<<"$pending"
}

# Replaces the value of KEY in an env file when it is present, appends it otherwise.
set_env_value() {
    local file="$1" key="$2" value="$3" tmp
    tmp="$(mktemp)"
    awk -v key="$key" -v value="$value" '
        BEGIN { done = 0 }
        index($0, key "=") == 1 { print key "=" value; done = 1; next }
        { print }
        END { if (!done) print key "=" value }
    ' "$file" >"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

# Succeeds when KEY has a non-empty value in the env file.
has_env_value() {
    local file="$1" key="$2"
    grep -Eq "^${key}=.+" "$file"
}

random_secret() {
    head -c 32 /dev/urandom | base64 | tr -d '\n'
}

ensure_env_files() {
    info "Checking .env files"
    local backend_env="backend/.env" frontend_env="frontend/.env"

    if [[ ! -f backend/.env.example || ! -f frontend/.env.example ]]; then
        problem "backend/.env.example or frontend/.env.example is missing." "initialise the submodules: git submodule update --init --recursive."
        return 0
    fi

    if [[ ! -f "$backend_env" ]]; then
        if ((DRY_RUN)); then
            printf '  + create %s from backend/.env.example (APP_KEY generated, APP_URL=http://localhost:%s)\n' "$backend_env" "$API_PORT"
        else
            cp backend/.env.example "$backend_env"
            set_env_value "$backend_env" APP_URL "http://localhost:${API_PORT}"
            ((PROD)) || set_env_value "$backend_env" CORS_ALLOWED_ORIGINS "http://localhost:${WEB_PORT}"
            ok "created $backend_env"
        fi
    else
        ok "$backend_env exists (values are never overwritten)"
    fi

    if [[ -f "$backend_env" ]] && ! has_env_value "$backend_env" APP_KEY; then
        if ((DRY_RUN)); then
            printf '  + generate APP_KEY in %s\n' "$backend_env"
        else
            set_env_value "$backend_env" APP_KEY "base64:$(random_secret)"
            ok "generated APP_KEY"
        fi
    fi

    if [[ ! -f "$frontend_env" ]]; then
        if ((DRY_RUN)); then
            printf '  + create %s from frontend/.env.example (VITE_API_BASE_URL on port %s)\n' "$frontend_env" "$API_PORT"
        else
            cp frontend/.env.example "$frontend_env"
            set_env_value "$frontend_env" VITE_API_BASE_URL "http://localhost:${API_PORT}/api/v1"
            ok "created $frontend_env"
        fi
    else
        ok "$frontend_env exists (values are never overwritten)"
    fi
}

port_in_use() {
    (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

# Ports owned by this very stack are fine: only foreign listeners are a problem.
stack_running() {
    [[ -n "$("${DC[@]}" ps --status running -q nginx 2>/dev/null)" ]]
}

check_ports() {
    info "Checking free ports"
    if ! docker_ready; then
        warn "Docker unavailable: cannot tell whether the ports belong to this stack"
    elif stack_running; then
        ok "stack already running: ports belong to it"
        return 0
    fi

    if port_in_use "$API_PORT"; then
        problem "port ${API_PORT} (API) is already in use." "choose another one, e.g. API_PORT=$((API_PORT + 100)) ./start.sh"
    else
        ok "API port ${API_PORT}"
    fi
    if ((PROD == 0)); then
        if port_in_use "$WEB_PORT"; then
            problem "port ${WEB_PORT} (SPA) is already in use." "choose another one, e.g. WEB_PORT=$((WEB_PORT + 1)) ./start.sh"
        else
            ok "SPA port ${WEB_PORT}"
        fi
    fi
}

confirm_reset() {
    printf '%sThis deletes the stack volumes (SQLite database and node_modules cache).%s\n' "$C_YELLOW" "$C_OFF"
    if ((DRY_RUN)); then
        printf '  + (would ask for a typed confirmation)\n'
        return 0
    fi
    if [[ ! -t 0 ]]; then
        problem "--reset needs an interactive terminal for its confirmation." "run it from a terminal, or remove the volumes yourself with 'docker compose down --volumes'."
    fi
    local answer
    read -r -p "Type 'reset' to confirm: " answer
    [[ "$answer" == "reset" ]] || problem "reset not confirmed." "type the word reset exactly, or run without --reset."
}

wait_for_url() {
    local name="$1" url="$2" service="$3" waited=0
    if ((DRY_RUN)); then
        printf '  + wait for %s at %s\n' "$name" "$url"
        return 0
    fi
    until curl -fsS -o /dev/null --max-time 3 "$url" 2>/dev/null; do
        if ((waited >= WAIT_SECONDS)); then
            problem "${name} did not answer at ${url} within ${WAIT_SECONDS}s." "inspect it with: ${DC[*]} logs ${service}"
        fi
        sleep 2
        waited=$((waited + 2))
    done
    ok "${name}: ${url}"
}

artisan() {
    local user_args=()
    ((PROD)) || user_args=(-u www-data)
    run "${DC[@]}" exec -T ${user_args[@]+"${user_args[@]}"} php php artisan "$@"
}

start_stack() {
    local build_args=()
    ((REBUILD)) && build_args=(--no-cache)

    info "Building images"
    run "${DC[@]}" build ${build_args[@]+"${build_args[@]}"}

    if ((PROD == 0)); then
        # The dev image ships Composer but no vendor directory (the source is bind-mounted).
        info "Installing backend dependencies"
        run "${DC[@]}" up -d --wait php
        run "${DC[@]}" exec -T -e COMPOSER_ALLOW_SUPERUSER=1 php composer install --no-interaction --prefer-dist --no-progress
    fi

    info "Starting containers"
    run "${DC[@]}" up -d --wait

    info "Preparing the database"
    # Artisan runs as www-data in development: files created by root are not writable by PHP-FPM.
    if ((PROD)); then
        run "${DC[@]}" exec -T php touch database/sqlite/database.sqlite
    else
        run "${DC[@]}" exec -T -u www-data php touch database/sqlite/database.sqlite
    fi
    artisan migrate --force
    artisan db:seed --class="$REFERENCE_SEEDER" --force
    if ((DEMO)); then
        artisan db:seed --class="$DEMO_SEEDER" --force
    fi

    info "Waiting for health checks"
    wait_for_url "API /health" "http://localhost:${API_PORT}/health" nginx
    wait_for_url "API /ready" "http://localhost:${API_PORT}/ready" nginx
    if ((PROD == 0)); then
        wait_for_url "SPA" "http://localhost:${WEB_PORT}/" web
    fi
}

print_summary() {
    printf '\n%sExpenses Manager is up%s\n' "$C_BOLD" "$C_OFF"
    printf '  API:      http://localhost:%s/api/v1\n' "$API_PORT"
    printf '  Health:   http://localhost:%s/health  and  /ready\n' "$API_PORT"
    if ((PROD)); then
        printf '  SPA:      not part of the production compose file (see README, "Production stack")\n'
    else
        printf '  SPA:      http://localhost:%s\n' "$WEB_PORT"
    fi
    if ((DRY_RUN == 0)) && curl -fsS -o /dev/null --max-time 3 "http://localhost:${API_PORT}/docs" 2>/dev/null; then
        printf '  API docs: http://localhost:%s/docs\n' "$API_PORT"
    else
        printf '  API docs: no docs UI is served by the backend; the contract is contracts/openapi.yaml\n'
    fi
    if ((DEMO)); then
        printf '  Demo login: %s / %s\n' "$DEMO_EMAIL" "$DEMO_PASSWORD"
    fi
    printf '  Stop:     ./start.sh --down%s\n' "$( ((PROD)) && printf ' --prod')"
}

run_tests() {
    info "Backend: Pint, Larastan and Pest (coverage gate 90%)"
    run docker build -f backend/docker/Dockerfile --target test -t expenses-backend:test backend
    run docker run --rm expenses-backend:test vendor/bin/pint --test
    run docker run --rm expenses-backend:test vendor/bin/phpstan analyse --memory-limit=1G
    run docker run --rm expenses-backend:test

    info "Frontend: ESLint, Prettier, vue-tsc and Vitest (coverage gate 90%)"
    run docker compose build web
    # CI=true lets pnpm refresh node_modules without a TTY (-T); otherwise it aborts with ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY.
    run docker compose run --rm --no-deps -T -e CI=true web pnpm lint
    run docker compose run --rm --no-deps -T -e CI=true web pnpm typecheck
    run docker compose run --rm --no-deps -T -e CI=true web pnpm coverage
    ok "test suites finished (Playwright suites need browsers: use make e2e)"
}

main() {
    parse_args "$@"

    if ((PROD)); then
        API_PORT="${API_PORT:-$PROD_API_PORT}"
    else
        API_PORT="${API_PORT:-$DEV_API_PORT}"
    fi
    WEB_PORT="${WEB_PORT:-$DEFAULT_WEB_PORT}"
    export API_PORT WEB_PORT

    DC=(docker compose)
    ((PROD)) && DC=(docker compose -f docker-compose.prod.yml)

    ((DRY_RUN)) && info "Dry run: nothing will be changed"

    check_prerequisites

    if ((TEST)); then
        run_tests
        return 0
    fi

    if ((LOGS && ! DEMO && ! REBUILD && ! RESET && ! DOWN)); then
        run "${DC[@]}" logs -f
        return 0
    fi

    if ((DOWN || RESET)); then
        if ((RESET)); then
            confirm_reset
            info "Stopping the stack and deleting its volumes"
            run "${DC[@]}" down --volumes
        else
            info "Stopping the stack"
            run "${DC[@]}" down
        fi
        ((DOWN)) && return 0
    fi

    init_submodules
    ensure_env_files
    check_ports
    start_stack
    print_summary

    if ((LOGS)); then
        run "${DC[@]}" logs -f
    fi
}

main "$@"
