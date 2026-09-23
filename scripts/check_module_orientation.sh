#!/usr/bin/env bash
#
# A module past the file-count trigger carries a README.
#
# Below the trigger, the file names are the orientation. Above it, a newcomer —
# human or agent — cannot tell what the module is for or which constraints it
# holds without reading all of it, and will make a locally reasonable change
# that is globally wrong.
#
# Scoped to the diff: a module this change touched must be oriented, so a module
# gets its README as it grows past the trigger. Modules already over it are debt.
# GATE_SCOPE=all reviews every module.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

# Directories containing a file this change touched, deletions included:
# removing a module's README touches that module. Read line by line, not through
# xargs: GNU xargs runs `dirname` once with no argument on an empty diff, and
# word-splitting breaks paths that contain spaces. A pipeline throughout, so a
# failing selector fails the gate rather than reading as an empty change.
missing=$(
    GATE_INCLUDE_DELETED=1 "$script_dir/lib/target_files.sh" '*' \
        | while IFS= read -r file; do dirname "$file"; done \
        | sort -u \
        | while IFS= read -r dir; do
            [ -d "$dir" ] || continue
            count=$(find "$dir" -maxdepth 1 -name '*.rs' -type f | wc -l | tr -d ' ')
            [ "$count" -gt "$MODULE_README_TRIGGER" ] || continue
            [ -f "$dir/README.md" ] && continue
            echo "  $dir — $count files, no README.md"
        done
)

if [ -n "$missing" ]; then
    echo "❌ Modules past the orientation trigger with no README:"
    printf '%s\n' "$missing"
    echo ""
    echo "Add a short README: purpose in one sentence, public API, pattern, gotchas."
    exit 1
fi

echo "✅ Modules past the trigger carry orientation"
