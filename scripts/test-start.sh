#!/usr/bin/env bash
# Behaviour tests for start.sh that need neither Docker nor network access.
# Usage: scripts/test-start.sh
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

if ((failures > 0)); then
    echo "test-start: $failures failure(s)" >&2
    exit 1
fi
echo "test-start: all checks passed"
