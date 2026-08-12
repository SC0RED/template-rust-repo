#!/usr/bin/env bash
#
# Errors may only be absorbed at a declared boundary.
#
# Everywhere else a failure must propagate (`?`), carry context and rethrow, or
# become a typed error. Quietly swapping a failure for a default value is the
# most expensive habit in the codebase: the operator who needs the failure
# never sees it, and the caller can't tell success from silence.
#
# Boundaries are declared in scripts/gates.conf (ERROR_BOUNDARIES) — process
# entry points and top-level orchestrators that must not crash the daemon.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

# Constructs that absorb an error rather than propagate it.
absorbing='\.unwrap_or\(|\.unwrap_or_default\(\)|\.unwrap_or_else\(|\.ok\(\)|if let Err\(_\)|Err\(_\)[[:space:]]*=>|let _ =[[:space:]]*[a-z_]*\('

# A fallible integer conversion clamped to a bound is saturating arithmetic,
# not error handling — there is no failure here for an operator to learn about.
not_error_handling='try_from\('

boundary_filter='^$'
if [ -n "$ERROR_BOUNDARIES" ]; then
    boundary_filter="$(echo "$ERROR_BOUNDARIES" | tr ' ' '\n' | paste -sd'|' -)"
fi

violations=$(
    "$script_dir/lib/list_production_lines.sh" \
        | grep -E "$absorbing" \
        | grep -vE "$not_error_handling" \
        | grep -vE "^($boundary_filter):" \
        || true
)

if [ -n "$violations" ]; then
    echo "❌ Errors absorbed outside a declared boundary:"
    echo "$violations"
    echo ""
    echo "Propagate with '?', add context and return a typed error, or — if this"
    echo "genuinely is a boundary — add the file to ERROR_BOUNDARIES in"
    echo "scripts/gates.conf and say why in the commit message."
    exit 1
fi

echo "✅ Errors absorbed only at declared boundaries"
