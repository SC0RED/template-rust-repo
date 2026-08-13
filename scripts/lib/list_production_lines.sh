#!/usr/bin/env bash
#
# Emit "path:lineno:text" for every production line under src/.
#
# Rust unit tests live inline in `#[cfg(test)] mod tests { ... }` blocks, so a
# plain grep over src/ can't tell production code from test code. This walks
# the braces to find where each test module actually ends, rather than assuming
# it runs to the end of the file — code placed after a test module is still
# production code and still has to pass the gates.
#
# Gates that must not fire on test code source this list instead of grepping
# src/ directly.
#
set -euo pipefail

"$(cd "$(dirname "$0")" && pwd)/target_files.sh" | while IFS= read -r file; do
    awk -v path="$file" '
        # Entering a #[cfg(test)] block: start counting braces from the next
        # line until they balance back to zero.
        /^[[:space:]]*#\[cfg\(test\)\]/ { in_test = 1; depth = 0; seen_brace = 0; next }

        in_test {
            n = gsub(/\{/, "{"); depth += n
            n = gsub(/\}/, "}"); depth -= n
            if (n > 0 || depth > 0) seen_brace = 1
            # Balanced again after having opened at least one brace: the test
            # module is closed and what follows is production code.
            if (seen_brace && depth <= 0) in_test = 0
            next
        }

        { print path ":" NR ":" $0 }
    ' "$file"
done
