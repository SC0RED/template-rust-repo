#!/usr/bin/env bash
#
# Files and functions stay within their budgets.
#
# The budget is a smoke alarm, not a design rule: past it, a file has almost
# always accumulated a second responsibility. Split at that boundary, never at
# the line number — a file cut arbitrarily at 300 lines is two bad files.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

# Count production lines per file in one pass. Calling the helper once per file
# rescans the whole tree for each file, which is invisible on a template and
# takes minutes on a real service.
over_files=$(
    "$script_dir/lib/list_production_lines.sh" \
        | cut -d: -f1 \
        | uniq -c \
        | awk -v budget="$MAX_FILE_LINES" '$1 > budget { printf "  %s — %d lines (budget %d)\n", $2, $1, budget }'
)

over_fns=$(awk -v budget="$MAX_FUNCTION_LINES" '
    /^[[:space:]]*(pub )?(async )?fn / { name=$0; start=NR; depth=0; open=0 }
    start {
        n=gsub(/\{/,"{"); depth+=n; if (n>0) open=1
        n=gsub(/\}/,"}"); depth-=n
        if (open && depth<=0) {
            if (NR-start > budget) printf "  %s:%d — %d lines (budget %d)\n", FILENAME, start, NR-start, budget
            start=0
        }
    }
' $(find src -name '*.rs' -type f) 2>/dev/null || true)

if [ -n "$over_files" ] || [ -n "$over_fns" ]; then
    echo "❌ Over the size budget:"
    [ -n "$over_files" ] && printf '%s' "$over_files"
    [ -n "$over_fns" ] && printf '%s\n' "$over_fns"
    echo "Split at a responsibility boundary, not at the line count."
    exit 1
fi

echo "✅ Files and functions within budget"
