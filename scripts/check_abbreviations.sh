#!/usr/bin/env bash
#
# Forbid common abbreviations in src/ — use full words (message not msg,
# request not req, context not ctx, ...).
#
# Identifier-aware: a token adjacent to a hyphen is not a Rust identifier (Rust
# identifiers cannot contain '-'), so hyphenated strings like "request-123" are
# not flagged. The list is intentionally conservative — it excludes tokens that
# collide with idiomatic Rust (cfg, impl, err/Err). Extend it as needed.
#
set -euo pipefail

abbreviations='msg|req|resp|ctx|mgr|usr|pwd|tmp|temp|btn'
boundary='[^A-Za-z0-9_-]'
pattern="(^|${boundary})(${abbreviations})(${boundary}|$)"

if matches=$(grep -rnE "$pattern" src/ 2>/dev/null); then
    echo "❌ Forbidden abbreviations found (use full words):"
    echo "$matches"
    exit 1
fi

echo "✅ No forbidden abbreviations"
