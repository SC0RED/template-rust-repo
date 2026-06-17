#!/bin/bash
# Claude Code PreToolUse hook: block shell commands that can destroy another
# agent's work in a shared checkout, or clobber a deploy box.
#
#   1. Destructive git (reset --hard/--merge, restore, checkout --, clean -f,
#      stash drop/clear, branch -D): erases uncommitted work that may belong to
#      a concurrent agent session.
#   2. git push --force / -f: rewrites history other agents have built on.
#   3. --no-verify: skips the git hooks that gate commits/pushes.
#   4. Raw rsync/scp TO a deploy box: a sync from a stale tree reverts
#      box-only changes. (Off by default — set GUARD_DEPLOY_BOXES below to your
#      hosts, e.g. an extended regex like 'box1|10\.0\.0\.5', to enable.)
#
# The harness runs this before the Bash tool call executes; exit 2 blocks the
# call and shows the agent the message on stderr.
#
# Requires: jq

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

# Deploy hosts to protect from raw rsync/scp pushes. Empty = rule disabled.
# Consuming repos fill this in (Agency protects its winston/builder boxes).
GUARD_DEPLOY_BOXES="${GUARD_DEPLOY_BOXES:-}"

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

block() {
    echo "BLOCKED by .claude/hooks/guard-bash.sh: $1" >&2
    exit 2
}

if echo "$CMD" | grep -qE '\bgit\b[^|;&]*[[:space:]](reset[[:space:]]+--(hard|merge)|restore[[:space:]]|checkout[[:space:]]+(--[[:space:]]|\.[[:space:]]|\.$)|clean[[:space:]]+-[A-Za-z]*f|stash[[:space:]]+(drop|clear)|branch[[:space:]]+-D[[:space:]])'; then
    block "destructive git operation (reset --hard / restore / checkout -- / clean -f / stash drop / branch -D). These erase uncommitted work that may belong to another agent session. If it is genuinely needed, ask the human operator to run it themselves."
fi

if echo "$CMD" | grep -qE '\bgit\b[^|;&]*[[:space:]]push[^|;&]*([[:space:]]--force([[:space:]]|$|-with-lease)|[[:space:]]-f([[:space:]]|$))'; then
    block "git push --force rewrites history other agents have built on. Push a new branch instead."
fi

if echo "$CMD" | grep -qE '\bgit\b[^|;&]*--no-verify'; then
    block "--no-verify skips the repo's git hooks, which exist to gate exactly this. Fix what the hook is complaining about instead."
fi

if [ -n "$GUARD_DEPLOY_BOXES" ]; then
    if echo "$CMD" | grep -qE "\brsync\b[^|;&]*[[:space:]]([^[:space:]]*@)?(${GUARD_DEPLOY_BOXES}):"; then
        block "raw rsync to a deploy box can revert box-only changes. Use the repo's reviewed deploy path (which diffs box vs repo first). Pulls (box -> local) are fine."
    fi
    LAST_TOKEN=$(echo "$CMD" | awk '{print $NF}')
    if echo "$CMD" | grep -qE '\bscp\b' && echo "$LAST_TOKEN" | grep -qE "^([^[:space:]]*@)?(${GUARD_DEPLOY_BOXES}):"; then
        block "scp TO a deploy box bypasses the deploy sweep. Pulls (box -> local) are fine; pushes go through the reviewed deploy path."
    fi
fi

exit 0
