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

# Constructs that look absorbing on one line but are not, read as a whole
# statement:
#   try_from(..).unwrap_or(MAX)  saturating arithmetic, no failure to report
#   .ok()?  and  .ok().ok_or(..)  convert then propagate — the caller still sees it
# Each is cut out of the statement before it is searched, rather than excusing
# the whole statement: a statement that propagates one failure and swallows
# another is still a swallow.
not_error_handling='try_from\(([^()]|\([^()]*\))*\)[[:space:]]*\.unwrap_or(_else)?\(|\.ok\(\)[[:space:]]*(\?|\.ok_or|\.context)'

# Space-separated path lists from gates.conf, as regex alternatives. Empty words
# are dropped: a stray double space would otherwise add an empty alternative,
# which matches every path and switches the gate off.
alternatives() {
    printf '%s\n' "$1" | tr -s '[:space:]' '\n' | sed '/^$/d' | paste -sd'|' -
}

# Declared boundaries, and paths whose code is not request-path Rust and so is
# not what this gate is for. `^$` matches no record when a list is empty.
boundary_filter="$(alternatives "$ERROR_BOUNDARIES")"
excluded_filter="$(alternatives "${ERROR_BOUNDARY_EXCLUDED_PATHS:-}")"

# Read whole statements, not lines: a `.ok()` followed by `?` on the next line
# propagates, and a line-at-a-time gate would call it a swallow.
violations=$(
    "$script_dir/lib/list_production_statements.sh" \
        | ABSORBING="$absorbing" NOT_ERROR_HANDLING="$not_error_handling" awk '
            { searched = $0; gsub(ENVIRON["NOT_ERROR_HANDLING"], "", searched) }
            searched ~ ENVIRON["ABSORBING"]
        ' \
        | { grep -vE "^(${boundary_filter:-^$}):" || true; } \
        | { grep -vE "^(${excluded_filter:-^$})" || true; }
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
