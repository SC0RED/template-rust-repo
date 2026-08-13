#!/usr/bin/env bash
#
# Emit "path:lineno:statement" for every production statement under src/.
#
# Rust chains span lines. A `.ok()` on its own line followed by `?` on the next
# propagates the failure — it is not a swallow — but a gate that reads one line
# at a time cannot see the `?`. Reading whole statements is the difference
# between a gate people trust and one they learn to ignore.
#
# A statement runs until a `;` or a `{`/`}` at brace depth zero. The reported
# line number is where it started, which is where a reader will look.
#
# Test code is excluded the same way list_production_lines.sh excludes it: by
# walking braces to find where each `#[cfg(test)]` module actually ends.
#
set -euo pipefail

"$(cd "$(dirname "$0")" && pwd)/target_files.sh" | while IFS= read -r file; do
    awk -v path="$file" '
        # Skip the body of any #[cfg(test)] module, brace-matched.
        /^[[:space:]]*#\[cfg\(test\)\]/ { in_test = 1; depth = 0; seen = 0; next }
        in_test {
            n = gsub(/\{/, "{"); depth += n; if (n > 0) seen = 1
            n = gsub(/\}/, "}"); depth -= n
            if (seen && depth <= 0) in_test = 0
            next
        }

        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (statement == "") start = NR
            statement = statement (statement == "" ? "" : " ") line

            # A statement ends at a semicolon or a brace, outside of both.
            if (line ~ /;[[:space:]]*$/ || line ~ /[{}][[:space:]]*$/) {
                print path ":" start ":" statement
                statement = ""
            }
        }
        END { if (statement != "") print path ":" start ":" statement }
    ' "$file"
done
