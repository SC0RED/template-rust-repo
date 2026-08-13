#!/usr/bin/env bash
#
# The agent instruction file stays within its line budget.
#
# An instruction file that grows without bound trains readers to skim it, which
# costs most on the parts that exist *only* as instruction — the architectural
# context no linter can carry. Detail belongs in docs/ with a pointer from here.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

failed=""
for file in CLAUDE.md AGENTS.md; do
    [ -f "$file" ] || continue
    lines=$(wc -l < "$file" | tr -d ' ')
    if [ "$lines" -gt "$AGENT_INSTRUCTIONS_MAX_LINES" ]; then
        failed="$failed  $file — $lines lines (budget $AGENT_INSTRUCTIONS_MAX_LINES)"$'\n'
    fi
done

if [ -n "$failed" ]; then
    echo "❌ Agent instruction file over budget:"
    printf '%s' "$failed"
    echo ""
    echo "Move detail into docs/ and reference it. Delete anything a gate already enforces."
    exit 1
fi

echo "✅ Agent instruction files within budget"
