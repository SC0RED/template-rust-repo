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

over_files=""
while IFS= read -r -d '' file; do
    # Production lines only — inline #[cfg(test)] modules are not the file's job.
    lines=$("$script_dir/lib/list_production_lines.sh" | grep -c "^$file:" || true)
    [ "$lines" -gt "$MAX_FILE_LINES" ] && over_files="$over_files  $file — $lines lines (budget $MAX_FILE_LINES)"$'\n'
done < <(find src -name '*.rs' -type f -print0)

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
