#!/usr/bin/env bash
#
# This file is part of Telegram Desktop,
# the official desktop application for the Telegram messaging service.
#
# For license and copyright information please follow this link:
# https://github.com/telegramdesktop/tdesktop/blob/master/LEGAL

# Merges an upstream release into the fork. Unlike the PowerShell script this
# one keeps the conflicts in the worktree instead of aborting: every sync so
# far had conflicts in fork code, and resolving them is the whole job.

set -euo pipefail

remote=upstream
repository=https://github.com/telegramdesktop/tdesktop.git
apply=false
ref=

usage() {
    cat <<'USAGE'
Usage: scripts/sync_upstream.sh [--ref vX.Y.Z] [--apply]

  --ref     upstream tag to merge, defaults to the newest vX.Y.Z
  --apply   actually create the branch and merge, otherwise only report

Without --apply nothing is written. With it, conflicts are left in the
worktree for manual resolution and the script prints what to do next.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ref) ref=$2; shift 2 ;;
        --apply) apply=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

if [ -n "$(git status --porcelain)" ]; then
    echo 'The worktree is dirty, commit or stash first.' >&2
    exit 1
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
    git remote add "$remote" "$repository"
fi

if [ -z "$ref" ]; then
    echo 'Looking up the newest stable tag...'
    ref=$(git ls-remote --tags --refs "$remote" 'v[0-9]*' \
        | sed 's|.*refs/tags/||' \
        | sort -V \
        | tail -1)
fi

echo "Fetching $ref..."
git fetch --no-tags "$remote" "refs/tags/$ref:refs/tags/$ref" 2>&1 | tail -2

current=$(git rev-parse --abbrev-ref HEAD)
behind=$(git rev-list --count "HEAD..$ref")
ahead=$(git rev-list --count "$ref..HEAD")

echo ''
echo "Current branch:   $current"
echo "Upstream ref:     $ref"
echo "Commits upstream: $behind"
echo "Commits in fork:  $ahead"

if [ "$behind" -eq 0 ]; then
    echo 'Already up to date.'
    exit 0
fi

if [ "$apply" != true ]; then
    echo ''
    echo 'Preview only. Re-run with --apply to merge.'
    exit 0
fi

branch="sync/upstream/$ref"
echo ''
echo "Creating $branch..."
git checkout -b "$branch"

set +e
git merge --no-ff --no-commit "$ref"
merged=$?
set -e

conflicts=$(git diff --name-only --diff-filter=U)
if [ -z "$conflicts" ] && [ $merged -eq 0 ]; then
    echo 'Merged without conflicts.'
else
    echo ''
    echo 'Conflicts to resolve by hand:'
    echo "$conflicts" | sed 's/^/  /'
fi

cat <<NEXT

Next steps:
  1. Resolve the conflicts, keeping the fork behaviour.
  2. python tools/verify_private_fork.py --require-autoupdate
  3. python tools/check_merge_artifacts.py $current $ref
     Both sides adding the same declaration merges without a conflict and
     only fails at compile time.
  4. git commit, push the branch and run the Windows x64 workflow on it.
  5. Fast-forward main once the workflow is green, then tag ayugram-$ref.
NEXT
