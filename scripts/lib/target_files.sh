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
# Usage: target_files.sh [glob]     (default '*.rs')
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

pattern="${1:-*.rs}"
scope="${GATE_SCOPE:-diff}"
base="${GATE_DIFF_BASE:-origin/development}"

emit_all() { find src -name "$pattern" -type f | sort; }

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

# Deleted files are excluded: a gate cannot read them, and their violations
# left with them.
git diff --name-only --diff-filter=d "$merge_base" HEAD -- 'src' \
    | grep -E "${pattern//\*/.*}$" \
    | while IFS= read -r file; do [ -f "$file" ] && echo "$file"; done \
    | sort
