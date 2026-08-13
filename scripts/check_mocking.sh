#!/usr/bin/env bash
#
# Only process-external dependencies may be mocked.
#
# Mocking a collaborator that lives in this process couples the test to the
# shape of the code rather than its behavior: the test passes, the refactor
# breaks it, and nobody learns anything about whether the system works. Network
# clients, clocks, and filesystems are different — those are genuinely outside,
# and faking them is the only way to test deterministically.
#
# The allowlist is MOCKABLE_TRAITS in scripts/gates.conf.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

mocked=$(grep -rnE '#\[(cfg_attr\(test, )?automock' src/ 2>/dev/null || true)
mocked="$mocked"$'\n'$(grep -rnE '^[[:space:]]*mock!' src/ 2>/dev/null || true)

allow_filter='^$'
if [ -n "$MOCKABLE_TRAITS" ]; then
    allow_filter="$(echo "$MOCKABLE_TRAITS" | tr ' ' '\n' | paste -sd'|' -)"
fi

violations=$(echo "$mocked" | grep -vE '^[[:space:]]*$' | grep -vE "$allow_filter" || true)

if [ -n "$violations" ]; then
    echo "❌ Mocks on collaborators that are not process-external:"
    echo "$violations"
    echo ""
    echo "Test the real collaborator. If this dependency really does cross the"
    echo "process boundary, add its trait to MOCKABLE_TRAITS in scripts/gates.conf."
    exit 1
fi

echo "✅ Mocking confined to process-external dependencies"
