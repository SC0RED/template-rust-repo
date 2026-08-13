#!/usr/bin/env bash
#
# Files that define failure behavior carry a higher coverage bar.
#
# Repo-wide coverage averages the error paths away: the happy path is easy to
# cover, so a comfortable overall number can sit on top of error handling that
# has never once executed. Those are exactly the branches that run on the worst
# day. This gate applies FAILURE_PATH_COVERAGE_MIN to the files that declare a
# typed error or act as a declared boundary.
#
# Reads the lcov.info that `make test` produces.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

if [ ! -f lcov.info ]; then
    echo "⚠️  lcov.info not found — run 'make test' first. Skipping."
    exit 0
fi

# Failure-path files: anything deriving a typed error, plus the declared boundaries.
failure_files=$(grep -rlE '#\[derive\([^)]*Error' src/ 2>/dev/null || true)
for boundary in $ERROR_BOUNDARIES; do
    failure_files="$failure_files"$'\n'"$boundary"
done
excluded_filter='^$'
if [ -n "${COVERAGE_EXCLUDED_PATHS:-}" ]; then
    excluded_filter="$(echo "$COVERAGE_EXCLUDED_PATHS" | tr ' ' '\n' | paste -sd'|' -)"
fi

failure_files=$(
    echo "$failure_files" \
        | grep -vE '^[[:space:]]*$' \
        | grep -vE "^($excluded_filter)$" \
        | sort -u
)

if [ -z "$failure_files" ]; then
    echo "✅ No failure-path files identified — nothing to check"
    exit 0
fi

failed=""
while IFS= read -r file; do
    # lcov records per-file hit/found counts; sum them for this source file.
    stats=$(awk -v target="$file" '
        $0 ~ /^SF:/ { current = substr($0, 4); sub(/^.*\//, "", current)
                      want = target; sub(/^.*\//, "", want)
                      active = (current == want) }
        active && /^LF:/ { found += substr($0, 4) }
        active && /^LH:/ { hit   += substr($0, 4) }
        END { print found+0, hit+0 }
    ' lcov.info)

    found=$(echo "$stats" | cut -d' ' -f1)
    hit=$(echo "$stats" | cut -d' ' -f2)

    [ "$found" -eq 0 ] && continue

    percent=$(( hit * 100 / found ))
    if [ "$percent" -lt "$FAILURE_PATH_COVERAGE_MIN" ]; then
        failed="$failed  $file — ${percent}% (need ${FAILURE_PATH_COVERAGE_MIN}%)"$'\n'
    fi
done <<< "$failure_files"

if [ -n "$failed" ]; then
    echo "❌ Failure-path files below the coverage bar:"
    printf '%s' "$failed"
    echo ""
    echo "Add tests that exercise the error branches, not just the happy path."
    exit 1
fi

echo "✅ Failure-path coverage at or above ${FAILURE_PATH_COVERAGE_MIN}%"
