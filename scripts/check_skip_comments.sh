#!/usr/bin/env bash
#
# Forbid lint-suppression "skip comments" in src/.
# Clean code over suppression — fix the underlying issue, never silence it.
# (unwrap/expect in tests are allowed via clippy.toml, not via #[allow].)
#
set -euo pipefail

pattern='#!?\[allow\(|#\[rustfmt::skip\]|//[[:space:]]*rustfmt::skip'

if matches=$(grep -rnE "$pattern" src/ 2>/dev/null); then
    echo "❌ Forbidden skip/suppression comments found:"
    echo "$matches"
    echo ""
    echo "Fix the underlying issue instead of suppressing the lint."
    exit 1
fi

echo "✅ No skip comments"
