#!/usr/bin/env bash
#
# The repository must carry machine-readable project context.
#
# Documentation an agent might read is weaker than context an agent always
# receives. openspec/config.yaml is injected into every planning request; a
# README is opened only if someone thinks to. This gate exists because that
# difference is the difference between a standard that holds and one that is
# merely written down.
#
set -euo pipefail

config="openspec/config.yaml"

if [ ! -f "$config" ]; then
    echo "❌ Missing $config — project constraints reach the agent only by chance."
    echo "   Create it with a 'context:' block describing the stack and its hard rules."
    exit 1
fi

if ! python3 -c "import yaml,sys; yaml.safe_load(open('$config'))" 2>/dev/null; then
    echo "❌ $config is not valid YAML — OpenSpec will ignore it silently."
    exit 1
fi

if ! python3 -c "
import yaml,sys
d = yaml.safe_load(open('$config')) or {}
sys.exit(0 if (d.get('context') or '').strip() else 1)
" 2>/dev/null; then
    echo "❌ $config has no 'context:' block — the file exists but carries nothing."
    exit 1
fi

echo "✅ Machine-readable project context present"
