#!/usr/bin/env bash
#
# One change should land inside one seam.
#
# When a single behavior change forces edits across many top-level modules, the
# boundary is in the wrong place — the modules aren't independent, they're
# entangled. This gate won't tell you where the right seam is, but it will tell
# you when you've just paid the cost of the wrong one.
#
# A legitimately cross-cutting change (a rename, a new lint, a dependency bump)
# will trip this. That's the point: it should be a deliberate, stated exception,
# not a silent habit. Raise MAX_MODULES_PER_CHANGE in scripts/gates.conf, or
# split the change.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

if ! git rev-parse --verify --quiet "$BLAST_RADIUS_BASE" >/dev/null; then
    echo "✅ Base $BLAST_RADIUS_BASE not available — skipping blast-radius check"
    exit 0
fi

merge_base=$(git merge-base HEAD "$BLAST_RADIUS_BASE")
changed=$(git diff --name-only "$merge_base" HEAD -- 'src/*' || true)

if [ -z "$changed" ]; then
    echo "✅ No source changes — blast radius empty"
    exit 0
fi

# A top-level module is the first path segment under src/ (a directory, or a
# bare .rs file sitting directly in src/).
modules=$(echo "$changed" | sed 's|^src/||' | cut -d/ -f1 | sort -u)
count=$(echo "$modules" | wc -l | tr -d ' ')

if [ "$count" -gt "$MAX_MODULES_PER_CHANGE" ]; then
    echo "❌ Change touches $count top-level modules (limit $MAX_MODULES_PER_CHANGE):"
    echo "$modules" | sed 's/^/  /'
    echo ""
    echo "Split the change along the seam, or — if this genuinely is cross-cutting —"
    echo "raise MAX_MODULES_PER_CHANGE in scripts/gates.conf and say why."
    exit 1
fi

echo "✅ Blast radius: $count module(s), within limit $MAX_MODULES_PER_CHANGE"
