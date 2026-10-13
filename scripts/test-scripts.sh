#!/usr/bin/env bash
# Behaviour tests for start.sh and check-readme.sh that need neither Docker nor network access.
# Usage: scripts/test-scripts.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

failures=0

# expect <description> <expected exit code> <expected output substring> -- <command...>
expect() {
    local description="$1" code="$2" needle="$3" output status=0
    shift 4
    output="$("$@" 2>&1)" || status=$?
    if [[ "$status" -ne "$code" || "$output" != *"$needle"* ]]; then
        echo "FAIL: $description (exit $status, wanted $code and '$needle')" >&2
        failures=$((failures + 1))
    else
        echo "ok:   $description"
    fi
}

expect "--help lists every flag" 0 "--reset" -- ./start.sh --help
expect "unknown flag is rejected" 2 "Unknown option" -- ./start.sh --nope
expect "--demo and --prod conflict" 2 "cannot be combined" -- ./start.sh --prod --demo
expect "dry run seeds Reference data" 0 "ReferenceSeeder" -- env NO_COLOR=1 ./start.sh --dry-run
if env NO_COLOR=1 ./start.sh --dry-run 2>&1 | grep -q "DemoSeeder"; then
    echo "FAIL: dry run must not seed Demo data without --demo" >&2
    failures=$((failures + 1))
else
    echo "ok:   dry run skips Demo without --demo"
fi
expect "--demo adds the Demo seeder" 0 "DemoSeeder" -- env NO_COLOR=1 ./start.sh --demo --dry-run
expect "--demo prints the demo login" 0 "demo@example.com" -- env NO_COLOR=1 ./start.sh --demo --dry-run
expect "API_PORT is honoured" 0 "http://localhost:8123/health" -- env NO_COLOR=1 API_PORT=8123 ./start.sh --dry-run
expect "WEB_PORT is honoured" 0 "http://localhost:5199/" -- env NO_COLOR=1 WEB_PORT=5199 ./start.sh --dry-run
expect "--prod uses the production compose file" 0 "docker-compose.prod.yml" -- env NO_COLOR=1 ./start.sh --prod --dry-run
expect "--prod defaults to port 8080" 0 "http://localhost:8080/health" -- env NO_COLOR=1 ./start.sh --prod --dry-run
expect "--rebuild disables the build cache" 0 "build --no-cache" -- env NO_COLOR=1 ./start.sh --rebuild --dry-run
expect "--down stops the stack" 0 "docker compose down" -- env NO_COLOR=1 ./start.sh --down --dry-run
expect "--reset deletes volumes after confirmation" 0 "down --volumes" -- env NO_COLOR=1 ./start.sh --reset --dry-run
expect "--test runs the backend gate" 0 "vendor/bin/phpstan" -- env NO_COLOR=1 ./start.sh --test --dry-run
expect "--test sets CI=true for the frontend gates" 0 "-e CI=true web pnpm coverage" -- env NO_COLOR=1 ./start.sh --test --dry-run

# check-readme.sh against throwaway READMEs (tick is a backtick, kept out of single quotes for shellcheck).
tick=$(printf '\140')
readme="$(mktemp)"
trap 'rm -f "$readme"' EXIT
check_readme() {
    README_FILE="$readme" scripts/check-readme.sh 2>&1
}
expect_readme() {
    local description="$1" code="$2" needle="$3" content="$4" output status=0
    printf '%s\n' "$content" >"$readme"
    output="$(check_readme)" || status=$?
    if [[ "$status" -ne "$code" || "$output" != *"$needle"* ]]; then
        echo "FAIL: $description (exit $status, wanted $code and '$needle')" >&2
        failures=$((failures + 1))
    else
        echo "ok:   $description"
    fi
}

expect_readme "check-readme accepts real references" 0 "valid" "Run ${tick}make test${tick} and ${tick}./start.sh --demo${tick}. Set ${tick}API_PORT${tick}."
expect_readme "check-readme ignores flags outside start.sh commands" 0 "valid" "Use ${tick}git commit --amend${tick}."
expect_readme "check-readme rejects a missing make target" 1 "target 'nope'" "Run ${tick}make nope${tick}."
expect_readme "check-readme rejects a missing sub-repo target" 1 "target 'nope'" "Run ${tick}make -C backend nope${tick}."
expect_readme "check-readme rejects a missing start.sh flag" 1 "no flag '--wat'" "Run ${tick}./start.sh --wat${tick}."
expect_readme "check-readme rejects an unknown env var" 1 "FOO_BAR" "Set ${tick}FOO_BAR${tick}."

# An env var counts as defined only when config assigns or reads it, so a prose mention must fail.
fixture="$(mktemp -d)"
mkdir "$fixture/scripts"
cp scripts/check-readme.sh "$fixture/scripts/"
printf '#!/usr/bin/env bash\n# PROSE_ONLY_NAME is mentioned in this comment only\nFIXTURE_ASSIGNED_NAME=1\n' >"$fixture/start.sh"
chmod +x "$fixture/start.sh"
printf 'Set %sFIXTURE_ASSIGNED_NAME%s.\n' "$tick" "$tick" >"$fixture/README.md"
expect "check-readme accepts a name assigned in a config file" 0 "valid" -- env README_FILE="$fixture/README.md" bash "$fixture/scripts/check-readme.sh"
printf 'Set %sPROSE_ONLY_NAME%s.\n' "$tick" "$tick" >"$fixture/README.md"
expect "check-readme rejects a name only mentioned in prose" 1 "PROSE_ONLY_NAME" -- env README_FILE="$fixture/README.md" bash "$fixture/scripts/check-readme.sh"
rm -rf "$fixture"

# ensure_env_files keeps the values a person wrote, but moves localhost URLs and the CORS origin list
# to the ports of this run, so an earlier run on other ports cannot break the SPA.
check_line() {
    local description="$1" file="$2" line="$3"
    if grep -qxF -- "$line" "$file"; then
        echo "ok:   $description"
    else
        echo "FAIL: $description (wanted '$line' in $file)" >&2
        failures=$((failures + 1))
    fi
}
# Runs ensure_env_files in a throwaway tree that holds the given backend and frontend env text.
# The caller sets API_PORT and WEB_PORT in the environment; the other flags are passed explicitly.
# Usage: sync_env <dir> <DRY_RUN> <PROD> <backend env> <frontend env>
sync_env() {
    local dir="$1" dry="$2" prod="$3" backend="$4" frontend="$5"
    mkdir -p "$dir/backend" "$dir/frontend"
    touch "$dir/backend/.env.example" "$dir/frontend/.env.example"
    printf '%s\n' "$backend" >"$dir/backend/.env"
    printf '%s\n' "$frontend" >"$dir/frontend/.env"
    (
        # shellcheck source=/dev/null
        source ./start.sh
        cd "$dir"
        export DRY_RUN="$dry" PROD="$prod"
        ensure_env_files >/dev/null
    )
}

dev="$(mktemp -d)"
API_PORT=8100 WEB_PORT=5174 sync_env "$dev" 0 0 \
    $'APP_URL=http://localhost:8000\nAPP_KEY=base64:keep\nCORS_ALLOWED_ORIGINS=http://localhost:5181,https://app.example.test' \
    'VITE_API_BASE_URL=https://demo.example.test/api/v1'
check_line "a stale localhost APP_URL follows the API port" "$dev/backend/.env" "APP_URL=http://localhost:8100"
check_line "CORS keeps the custom origin and adds the SPA origin" "$dev/backend/.env" "CORS_ALLOWED_ORIGINS=http://localhost:5181,https://app.example.test,http://localhost:5174"
check_line "the generated APP_KEY is kept" "$dev/backend/.env" "APP_KEY=base64:keep"
check_line "a non-localhost frontend API URL is left alone" "$dev/frontend/.env" "VITE_API_BASE_URL=https://demo.example.test/api/v1"
rm -rf "$dev"

prod="$(mktemp -d)"
API_PORT=8080 WEB_PORT=5174 sync_env "$prod" 0 1 \
    $'APP_URL=http://localhost:8000\nCORS_ALLOWED_ORIGINS=http://localhost:5181' \
    'VITE_API_BASE_URL=http://localhost:8000/api/v1'
check_line "production APP_URL follows the production port" "$prod/backend/.env" "APP_URL=http://localhost:8080"
check_line "production leaves CORS untouched" "$prod/backend/.env" "CORS_ALLOWED_ORIGINS=http://localhost:5181"
rm -rf "$prod"

dry="$(mktemp -d)"
API_PORT=8100 WEB_PORT=5174 sync_env "$dry" 1 0 \
    $'APP_URL=http://localhost:8000\nCORS_ALLOWED_ORIGINS=http://localhost:5181' \
    'VITE_API_BASE_URL=http://localhost:8011/api/v1'
check_line "a dry run does not rewrite APP_URL" "$dry/backend/.env" "APP_URL=http://localhost:8000"
check_line "a dry run does not rewrite CORS" "$dry/backend/.env" "CORS_ALLOWED_ORIGINS=http://localhost:5181"
check_line "a dry run does not rewrite the frontend API URL" "$dry/frontend/.env" "VITE_API_BASE_URL=http://localhost:8011/api/v1"
rm -rf "$dry"

if ((failures > 0)); then
    echo "test-scripts: $failures failure(s)" >&2
    exit 1
fi
echo "test-scripts: all checks passed"
