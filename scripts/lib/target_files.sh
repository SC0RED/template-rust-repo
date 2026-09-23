#!/usr/bin/env bash
#
# Emit the list of source files a gate should check.
#
# Adopting a gate on an existing codebase has a chicken-and-egg problem: the
# gate is right, the code predates it, and running it whole-repo on day one
# produces hundreds of findings nobody wrote today. People then turn the gate
# off, or learn to ignore red — and the gate has cost more than it bought.
#
# So the default scope is the diff: new and changed files must pass, and the
# rest is a known debt rather than a broken build. Quality can only improve,
# and nobody is blocked by code they did not touch.
#
# GATE_SCOPE=all overrides this, for the deliberate burndown pass and for a
# repository adopting the gates from empty.
#
# Usage: target_files.sh [glob] [directory]     (defaults '*.rs' and 'src')
#
# GATE_INCLUDE_DELETED=1 also emits files the diff deleted. A gate that judges a
# file by its neighbours — a module by its README, a migration by its reversal —
# needs to see the deletion, because deleting the neighbour is the violation.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

pattern="${1:-*.rs}"
directory="${2:-src}"
scope="${GATE_SCOPE:-diff}"
base="${GATE_DIFF_BASE:-origin/development}"

# Files that exist only under #[cfg(test)] — `foo_tests.rs`, `tests.rs` — are
# test code even though the marker lives in the parent that declares the module.
# The statement helpers can only see markers inside the file itself, so the
# name-level exclusion happens here, once, for every gate. Plural only: a
# production module can reasonably be called `load_test.rs`.
test_file='(_tests\.rs|/tests\.rs)$'

emit_all() {
    find "$directory" -name "$pattern" -type f 2>/dev/null \
        | { grep -vE "$test_file" || true; } \
        | sort
}

if [ "$scope" = "all" ]; then
    emit_all
    exit 0
fi

# No base to compare against — a fresh clone, a detached CI checkout, or a
# repository with no remote. Checking everything is the safe answer: better a
# noisy run than a silent one that checked nothing.
if ! git rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
    emit_all
    exit 0
fi

merge_base=$(git merge-base HEAD "$base" 2>/dev/null || echo "")
if [ -z "$merge_base" ]; then
    emit_all
    exit 0
fi

# Deleted files are excluded unless asked for: a gate that reads a file's own
# content cannot read them, and their violations left with them.
#
# A failing `git diff` must fail the gate. Swallowing it would turn "could not
# compare" into "nothing changed" and pass a run that checked nothing.
#
# An empty diff is the ordinary case — most branches touch no source at all — so
# grep finding nothing must not fail the pipeline. Under `pipefail` an unguarded
# grep turns "nothing changed" into a broken gate, which is how this first shipped.
include_deleted="${GATE_INCLUDE_DELETED:-0}"
diff_filter=d
[ "$include_deleted" = "1" ] && diff_filter=ACDMRT
changed=$(git diff --name-only --diff-filter="$diff_filter" "$merge_base" HEAD -- "$directory")
[ -z "$changed" ] && exit 0

printf '%s\n' "$changed" \
    | { grep -E "${pattern//\*/.*}$" || true; } \
    | { grep -vE "$test_file" || true; } \
    | while IFS= read -r file; do
        [ -n "$file" ] || continue
        [ "$include_deleted" = "1" ] || [ -f "$file" ] || continue
        echo "$file"
    done \
    | sort
