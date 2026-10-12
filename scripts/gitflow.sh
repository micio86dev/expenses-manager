#!/usr/bin/env bash
# Git Flow helper for feature and hotfix branches.
#
# Usage (run from the repository root, or pass the repository with -C):
#   scripts/gitflow.sh [-C <repo>] feature start <name>
#   scripts/gitflow.sh [-C <repo>] feature finish <name>
#   scripts/gitflow.sh [-C <repo>] hotfix start <name>
#   scripts/gitflow.sh [-C <repo>] hotfix finish <name>
#
# Refuses to run on a dirty working tree. Merges always use --no-ff.
set -euo pipefail

REPO="."
if [[ "${1:-}" == "-C" ]]; then
    REPO="${2:?missing repository path after -C}"
    shift 2
fi

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
}

die() {
    echo "gitflow: $*" >&2
    exit 1
}

git_in() {
    git -C "$REPO" "$@"
}

require_clean_tree() {
    if [[ -n "$(git_in status --porcelain)" ]]; then
        die "working tree is dirty; commit or stash changes first"
    fi
}

require_branch_exists() {
    git_in show-ref --verify --quiet "refs/heads/$1" || die "branch '$1' does not exist"
}

# Bootstraps the root repository: "git-flow" needs the develop branch to exist.
require_develop() {
    git_in show-ref --verify --quiet refs/heads/develop || die "branch 'develop' is missing"
}

[[ $# -ge 3 ]] || usage
kind="$1"
action="$2"
name="$3"

[[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "invalid name '$name' (use lowercase letters, digits, '.', '_' or '-')"

require_clean_tree
require_develop

case "$kind:$action" in
    feature:start)
        git_in show-ref --verify --quiet "refs/heads/feature/$name" && die "feature/$name already exists"
        git_in checkout -q -b "feature/$name" develop
        echo "Started feature/$name from develop"
        ;;
    feature:finish)
        require_branch_exists "feature/$name"
        git_in checkout -q develop
        git_in merge --no-ff -q "feature/$name" -m "merge: feature/$name into develop"
        git_in branch -q -d "feature/$name"
        echo "Merged feature/$name into develop"
        ;;
    hotfix:start)
        git_in show-ref --verify --quiet "refs/heads/hotfix/$name" && die "hotfix/$name already exists"
        git_in checkout -q -b "hotfix/$name" main
        echo "Started hotfix/$name from main"
        ;;
    hotfix:finish)
        require_branch_exists "hotfix/$name"
        git_in checkout -q main
        git_in merge --no-ff -q "hotfix/$name" -m "merge: hotfix/$name into main"
        git_in checkout -q develop
        git_in merge --no-ff -q "hotfix/$name" -m "merge: hotfix/$name into develop"
        git_in branch -q -d "hotfix/$name"
        echo "Merged hotfix/$name into main and develop; tag it with scripts/release.sh"
        ;;
    *)
        usage
        ;;
esac
