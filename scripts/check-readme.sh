#!/usr/bin/env bash
# Fails when README.md references something that does not exist:
#   - a `make` target (root Makefile, or the Makefile named with `make -C <dir>`)
#   - a start.sh flag (checked against `./start.sh --help`)
#   - an environment variable (checked against the env examples, compose files and scripts)
# Usage: scripts/check-readme.sh   (README_FILE=<path> checks another file; used by the tests)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

README="${README_FILE:-README.md}"
tick=$(printf '\140')
errors=0

fail() {
    echo "check-readme: $*" >&2
    errors=$((errors + 1))
}

makefile_targets() {
    grep -Eho '^[a-zA-Z0-9_-]+:' "$1/Makefile" | tr -d ':' | sort -u
}

contains_line() {
    grep -Fxq -- "$1"
}

# 1. make targets: "make <target>" and "make -C <dir> <target>" inside code spans or fences.
while IFS= read -r match; do
    dir="."
    target=""
    if [[ "$match" =~ ^make[[:space:]]+-C[[:space:]]+([a-zA-Z0-9_./-]+)[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
        dir="${BASH_REMATCH[1]}"
        target="${BASH_REMATCH[2]}"
    elif [[ "$match" =~ ^make[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
        target="${BASH_REMATCH[1]}"
    else
        continue
    fi
    if [[ ! -f "$dir/Makefile" ]]; then
        fail "'$match': no Makefile in '$dir'"
    elif ! makefile_targets "$dir" | contains_line "$target"; then
        fail "'$match': target '$target' does not exist in $dir/Makefile"
    fi
done < <(grep -Eo 'make (-C [a-zA-Z0-9_./-]+ )?[a-zA-Z0-9_-]+' "$README" | sort -u)

# 2. start.sh flags: every --flag in a `./start.sh ...` command, plus the first column of the flag table.
help_text="$(./start.sh --help)"
flags="$(
    {
        grep -Eo '\./start\.sh[^`]*' "$README" | grep -Eo -- '--[a-z][a-z-]*' || true
        sed -n '/^| Flag | Effect |/,/^$/p' "$README" | grep -Eo "^\\| ${tick}--[a-z-]+${tick}" | grep -Eo -- '--[a-z-]+' || true
    } | sort -u
)"
for flag in $flags; do
    grep -Eq -- "(^|[[:space:]])${flag}([[:space:],]|$)" <<<"$help_text" || fail "start.sh has no flag '$flag'"
done

# 3. environment variables: backticked UPPER_SNAKE names must be defined somewhere in the repository config.
known_sources=(
    backend/.env.example frontend/.env.example docker-compose.yml docker-compose.prod.yml start.sh
    backend/docker/php/entrypoint.sh frontend/docker/Dockerfile frontend/e2e-fullstack/env.ts
)
known="$(
    for file in "${known_sources[@]}"; do
        [[ -f "$file" ]] && grep -Eo '[A-Z][A-Z0-9]*(_[A-Z0-9]+)+' "$file"
    done | sort -u
)"
while IFS= read -r name; do
    if ! contains_line "$name" <<<"$known"; then
        fail "environment variable '$name' is not defined in any env example, compose file or script"
    fi
done < <(grep -Eo "${tick}[A-Z][A-Z0-9]*(_[A-Z0-9]+)+${tick}" "$README" | tr -d "$tick" | sort -u)

if ((errors > 0)); then
    echo "check-readme: $errors problem(s) found" >&2
    exit 1
fi
echo "check-readme: README references are valid"
