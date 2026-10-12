#!/usr/bin/env bash
# Release automation for the superproject and its submodules.
#
# Usage: scripts/release.sh <patch|minor|major>
#
# For each repository, in order: backend, frontend, then the root:
#   1. refuse dirty trees
#   2. compute the next version from the last vX.Y.Z tag (none -> 0.1.0)
#   3. create release/x.y.z from develop
#   4. update VERSION and CHANGELOG.md
#   5. merge into main with --no-ff and create an annotated tag vX.Y.Z
#   6. back-merge into develop and delete the release branch
# The root repository is released last so its submodule pointers reference the
# released commits of backend and frontend.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPOS=("backend" "frontend" ".")
FIRST_VERSION="0.1.0"

die() {
    echo "release: $*" >&2
    exit 1
}

[[ $# -eq 1 ]] || die "usage: scripts/release.sh <patch|minor|major>"
bump="$1"
[[ "$bump" =~ ^(patch|minor|major)$ ]] || die "unknown bump '$bump'"

git_in() {
    local repo="$1"
    shift
    git -C "$ROOT/$repo" "$@"
}

# Last vX.Y.Z tag reachable from main, or empty.
last_tag() {
    git_in "$1" describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' main 2>/dev/null || true
}

next_version() {
    local current="$1" major minor patch
    IFS=. read -r major minor patch <<<"$current"
    case "$bump" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "$major.$((minor + 1)).0" ;;
        patch) echo "$major.$minor.$((patch + 1))" ;;
    esac
}

# Subjects of non-merge commits on develop since a ref (or the full history), without release bookkeeping.
changes_since() {
    local repo="$1" since="$2" range="develop"
    [[ -z "$since" ]] || range="$since..develop"
    git_in "$repo" log --no-merges --invert-grep --grep='^chore(release)' --pretty='- %s' "$range"
}

# Fail fast on any dirty tree before touching anything.
for repo in "${REPOS[@]}"; do
    [[ -z "$(git_in "$repo" status --porcelain)" ]] || die "'$repo' has uncommitted changes"
    git_in "$repo" show-ref --verify --quiet refs/heads/develop || die "'$repo' has no develop branch"
    git_in "$repo" show-ref --verify --quiet refs/heads/main || die "'$repo' has no main branch"
done

release_repo() {
    local repo="$1" tag version branch changelog_entry today changelog_file

    tag="$(last_tag "$repo")"
    if [[ -z "$tag" ]]; then
        version="$FIRST_VERSION"
        changelog_entry="$(changes_since "$repo" "")"
    else
        version="$(next_version "${tag#v}")"
        changelog_entry="$(changes_since "$repo" "$tag")"
    fi
    [[ -n "$changelog_entry" ]] || changelog_entry="- No changes recorded."

    branch="release/$version"
    git_in "$repo" show-ref --verify --quiet "refs/heads/$branch" && die "'$repo' already has $branch"
    git_in "$repo" show-ref --verify --quiet "refs/tags/v$version" && die "'$repo' already has tag v$version"

    today="$(date +%F)"
    changelog_file="$ROOT/$repo/CHANGELOG.md"

    git_in "$repo" checkout -q -b "$branch" develop
    printf '%s\n' "$version" >"$ROOT/$repo/VERSION"

    {
        printf '# Changelog\n\n'
        printf '## [%s] - %s\n\n%s\n\n' "$version" "$today" "$changelog_entry"
        if [[ -f "$changelog_file" ]]; then
            tail -n +2 "$changelog_file" | sed '1{/^$/d;}'
        fi
    } >"$changelog_file.tmp"
    mv "$changelog_file.tmp" "$changelog_file"

    git_in "$repo" add VERSION CHANGELOG.md
    # The root pins the submodule commits that were just released.
    if [[ "$repo" == "." ]]; then
        git_in "$repo" add backend frontend
    fi
    git_in "$repo" commit -q -m "chore(release): $version"

    git_in "$repo" checkout -q main
    git_in "$repo" merge --no-ff -q "$branch" -m "merge: release $version into main"
    git_in "$repo" tag -a "v$version" -m "Release $version"

    git_in "$repo" checkout -q develop
    git_in "$repo" merge --no-ff -q "$branch" -m "merge: release $version back into develop"
    git_in "$repo" branch -q -d "$branch"

    echo "Released '$repo' as v$version"
}

for repo in "${REPOS[@]}"; do
    release_repo "$repo"
done
