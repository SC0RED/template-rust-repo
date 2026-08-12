#!/usr/bin/env bash
#
# Production code must not branch on whether it is under test.
#
# A `cfg!(test)` check or a TEST/CI environment probe inside a production path
# means the thing you shipped is not the thing you tested. Inject the
# dependency instead, or move the seam to a boundary where it's explicit.
#
# `#[cfg(test)] mod tests` is the normal way to attach unit tests to a module
# and is not what this gate is looking for — see lib/list_production_lines.sh.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"

seams='cfg!\(test\)|env::var\("(TEST|TESTING|CI|PYTEST[A-Z_]*)"|is_test|IS_TEST|#\[cfg\(feature = "test'

violations=$("$script_dir/lib/list_production_lines.sh" | grep -E "$seams" || true)

if [ -n "$violations" ]; then
    echo "❌ Production code branches on test state:"
    echo "$violations"
    echo ""
    echo "Inject the dependency the test needs to vary, or move the decision to"
    echo "a boundary where it is a normal, visible parameter."
    exit 1
fi

echo "✅ No test-only seams in production code"
