#!/usr/bin/env bash
# with-ephemeral-worktree.sh — run a command in a throwaway worktree pinned to
# a committed ref, then always tear it down.
#
# For headless/cron/CI jobs (a scheduled task, a scripted build/deploy) that
# must NOT touch the live checkout other agents are editing. Because the
# worktree is checked out at an explicit committed ref, the job can never see
# or destroy anyone's uncommitted work — it only ever observes history. The
# worktree is removed on exit even if the command fails.
#
# Usage:
#   scripts/with-ephemeral-worktree.sh <ref> -- <command> [args...]
#   scripts/with-ephemeral-worktree.sh development -- make check
#   scripts/with-ephemeral-worktree.sh "$GIT_SHA"  -- ./scripts/some-job.sh
#
# The command runs with CWD set to the ephemeral worktree root.
# Portable bash (macOS + Linux). Requires: git, mktemp.

set -uo pipefail

die() { echo "with-ephemeral-worktree: $*" >&2; exit 1; }

REF="${1:-}"
[ -n "$REF" ] || die "usage: with-ephemeral-worktree.sh <ref> -- <command...>"
shift
[ "${1:-}" = "--" ] || die "expected '--' separator before the command"
shift
[ "$#" -gt 0 ] || die "no command given after '--'"

command -v git >/dev/null 2>&1 || die "git not found"
MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)") \
    || die "not inside a git repository"

# Resolve to an immutable commit SHA so the run is reproducible even if the
# branch moves under us mid-job.
SHA=$(git -C "$MAIN_REPO" rev-parse --verify "${REF}^{commit}" 2>/dev/null) \
    || die "ref '$REF' does not resolve to a commit"

WT=$(mktemp -d "${TMPDIR:-/tmp}/ephemeral-worktree.XXXXXX") || die "mktemp failed"
cleanup() {
    git -C "$MAIN_REPO" worktree remove --force "$WT" 2>/dev/null \
        || rm -rf "$WT" 2>/dev/null || true
    git -C "$MAIN_REPO" worktree prune 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --detach: no branch, just the commit — nothing to collide with.
git -C "$MAIN_REPO" worktree add --detach "$WT" "$SHA" >&2 \
    || die "could not create ephemeral worktree at $SHA"

echo "with-ephemeral-worktree: running in $WT @ ${SHA:0:12}" >&2
( cd "$WT" && "$@" )
exit $?
