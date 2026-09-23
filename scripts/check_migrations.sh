#!/usr/bin/env bash
#
# Every migration must say how to undo it.
#
# A migration you can't reverse turns a bad deploy into an outage with no exit.
# Either ship a down-migration, or state in the file why reversal is impossible
# (a destructive drop, a one-way backfill) so the decision is deliberate and on
# the record rather than an omission nobody noticed.
#
# Repos with no migrations/ directory pass trivially — this gate travels with
# the catalog into repos that do have one.
#
# Scoped to the diff like the source gates: a migration added by this change
# must state its reversal, while ones that predate the gate are debt to burn
# down rather than a wall on day one. GATE_SCOPE=all reviews every migration.
#
set -euo pipefail

if [ ! -d migrations ]; then
    echo "✅ No migrations/ directory — nothing to check"
    exit 0
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

# The migrations this change touched, each named by its forward half. A changed
# or deleted .down.sql stands for its .up.sql: deleting the only reversal is the
# violation, and the untouched .up.sql is where it shows. A pipeline throughout,
# so a failing selector fails the gate rather than reading as an empty change.
missing=$(
    GATE_INCLUDE_DELETED=1 "$script_dir/lib/target_files.sh" '*.sql' migrations \
        | while IFS= read -r migration; do
            case "$migration" in
                (*.down.sql) echo "${migration%.down.sql}.up.sql" ;;
                (*) echo "$migration" ;;
            esac
        done \
        | sort -u \
        | while IFS= read -r migration; do
            [ -f "$migration" ] || continue

            # A reversal is either a paired .down.sql or an explicit, reasoned waiver.
            paired="${migration%.up.sql}.down.sql"
            [ "$paired" != "$migration" ] && [ -f "$paired" ] && continue
            grep -qiE '^--[[:space:]]*(rollback|irreversible):' "$migration" && continue

            echo "  $migration"
        done
)

if [ -n "$missing" ]; then
    echo "❌ Migrations with no stated reversal:"
    printf '%s\n' "$missing"
    echo ""
    echo "Add a paired .down.sql, or head the file with one of:"
    echo "  -- rollback: <how to undo this>"
    echo "  -- irreversible: <why this cannot be undone>"
    exit 1
fi

echo "✅ Every migration states its reversal"
