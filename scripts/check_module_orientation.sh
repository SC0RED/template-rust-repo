#!/usr/bin/env bash
#
# A module past the file-count trigger carries a README.
#
# Below the trigger, the file names are the orientation. Above it, a newcomer —
# human or agent — cannot tell what the module is for or which constraints it
# holds without reading all of it, and will make a locally reasonable change
# that is globally wrong.
#
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/gates.conf
source "$script_dir/gates.conf"

missing=""
while IFS= read -r -d '' dir; do
    count=$(find "$dir" -maxdepth 1 -name '*.rs' -type f | wc -l | tr -d ' ')
    [ "$count" -gt "$MODULE_README_TRIGGER" ] || continue
    [ -f "$dir/README.md" ] && continue
    missing="$missing  $dir — $count files, no README.md"$'\n'
done < <(find src -mindepth 1 -type d -print0)

if [ -n "$missing" ]; then
    echo "❌ Modules past the orientation trigger with no README:"
    printf '%s' "$missing"
    echo ""
    echo "Add a short README: purpose in one sentence, public API, pattern, gotchas."
    exit 1
fi

echo "✅ Modules past the trigger carry orientation"
