#!/bin/bash
# Claude Code PreToolUse hook: block Edit/Write in a repo's MAIN checkout.
#
# Multiple agent sessions share the main checkout; concurrent edits there
# destroy each other's uncommitted work. The rule: edits happen in a linked
# worktree (one per agent — see scripts/agent-wt.sh), never in the main
# checkout. The harness runs this before the tool call executes; exit 2 blocks
# the call and shows the agent the message on stderr.
#
# Requires: jq

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$FILE" ] || exit 0

# Write may target a not-yet-existing directory; walk up to one that exists.
DIR=$(dirname "$FILE")
while [ ! -d "$DIR" ] && [ "$DIR" != "/" ]; do DIR=$(dirname "$DIR"); done

GIT_DIR=$(git -C "$DIR" rev-parse --path-format=absolute --git-dir 2>/dev/null) || exit 0
COMMON_DIR=$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0

# In a linked worktree, --git-dir is .git/worktrees/<name> while
# --git-common-dir is the repo's .git. In the main checkout they are the
# same path — that is the shared tree nobody may edit.
if [ "$GIT_DIR" = "$COMMON_DIR" ]; then
    TOPLEVEL=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || echo "$DIR")
    REPO=$(basename "$TOPLEVEL")
    {
        echo "BLOCKED: $FILE is inside the MAIN checkout of $REPO, which is shared by every agent session."
        echo "Create an isolated worktree (with its own port + state) and edit there instead"
        echo "(replace feature/GH-123-short-desc with your branch — angle brackets omitted so this is copy-paste-safe):"
        echo "  cd \"\$(cd \"$TOPLEVEL\" && scripts/agent-wt.sh new feature/GH-123-short-desc)\""
        echo "  # or: make -C \"$TOPLEVEL\" agent slug=feature/GH-123-short-desc"
        echo "Then re-issue this edit against the file under that worktree."
        echo "Commit and push from the worktree; 'make agent-rm slug=...' when the branch is pushed."
        echo "See docs/guides/PARALLEL_AGENTS.md."
    } >&2
    exit 2
fi

exit 0
