#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/config/ai/claude-plugin"
ARTIFACT_DIR="${ROOT_DIR}/plugins/monika-claude"

rm -rf "${ARTIFACT_DIR}"
mkdir -p "${ARTIFACT_DIR}"

rsync -a \
  --exclude '.git/' \
  --exclude 'packaging/' \
  "${SOURCE_DIR}/" "${ARTIFACT_DIR}/"

cp "${SOURCE_DIR}/packaging/plugin.json" "${ARTIFACT_DIR}/.claude-plugin/plugin.json"
cp "${SOURCE_DIR}/packaging/marketplace.json" "${ARTIFACT_DIR}/.claude-plugin/marketplace.json"

cat > "${ARTIFACT_DIR}/README.md" <<'EOF'
# monika-claude

Claude plugin artifact for Miyago's Monika workflow.

## Includes

- SDD/TDD-oriented commands, agents, rules, and skills
- hooks and scripts for Claude Code workflow
- project bootstrap via `install.sh --project`

## Rebuild from source

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/claude-plugin/scripts/build-artifact.sh
```

## Validate

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/claude-plugin/scripts/validate-artifact.sh
```
EOF
