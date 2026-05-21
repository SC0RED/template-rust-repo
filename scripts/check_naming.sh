#!/usr/bin/env bash
#
# Forbid generic "junk drawer" file names in src/.
# Files must have a single, descriptive responsibility (retry.rs, ttl_cache.rs)
# — not utils.rs / helpers.rs / common.rs. `mod.rs` is exempt (it is Rust's
# module-root convention, not a junk drawer).
#
set -euo pipefail

matches=$(find src -type f \
    \( -name 'utils.rs' -o -name 'util.rs' \
    -o -name 'helpers.rs' -o -name 'helper.rs' \
    -o -name 'common.rs' -o -name 'misc.rs' \
    -o -name 'shared.rs' -o -name 'stuff.rs' \))

if [ -n "$matches" ]; then
    echo "❌ Generic file names found — rename to reflect a single responsibility:"
    echo "$matches"
    exit 1
fi

echo "✅ No generic file names"
