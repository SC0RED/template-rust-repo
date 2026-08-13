#!/usr/bin/env bash
#
# Loading a module does nothing.
#
# Import-time input/output, spawned work, or clock reads make load order
# significant — and load order is the hardest kind of dependency to see, because
# nothing in any signature mentions it. Initialization belongs in a function the
# caller invokes at a moment it chose.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

# Statics and consts initialised by calling something, rather than by a literal
# or a const fn, run that call at load. `lazy_static`/`OnceLock` defer to first
# use, which is the supported pattern and is not flagged.
# The helper emits "path:line:text", so these match mid-line rather than at ^.
effectful='(pub )?static [A-Z_]+[^=]*=[[:space:]]*[a-z_][a-z_:]*\(|(pub )?const [A-Z_]+[^=]*=[[:space:]]*[a-z_][a-z_:]*\('

violations=$("$script_dir/lib/list_production_lines.sh" | grep -E "$effectful" || true)

if [ -n "$violations" ]; then
    echo "❌ Work performed at module load:"
    echo "$violations"
    echo ""
    echo "Move it into an initializer the caller invokes, or defer with OnceLock."
    exit 1
fi

echo "✅ No import-time side effects"
