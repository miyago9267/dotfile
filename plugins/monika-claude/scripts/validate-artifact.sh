#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/plugins/monika-claude"

required_files=(
  "${ARTIFACT_DIR}/.claude-plugin/plugin.json"
  "${ARTIFACT_DIR}/.claude-plugin/marketplace.json"
  "${ARTIFACT_DIR}/README.md"
  "${ARTIFACT_DIR}/install.sh"
  "${ARTIFACT_DIR}/templates/AGENTS.md"
  "${ARTIFACT_DIR}/commands/plan.md"
  "${ARTIFACT_DIR}/skills/sdd/SKILL.md"
  "${ARTIFACT_DIR}/hooks/hooks.json"
)

for file in "${required_files[@]}"; do
  [[ -f "${file}" ]] || {
    echo "missing required file: ${file}" >&2
    exit 1
  }
done

grep -q '"name": "monika-claude"' "${ARTIFACT_DIR}/.claude-plugin/plugin.json" || {
  echo "artifact plugin manifest missing monika-claude name" >&2
  exit 1
}

grep -q '"name": "monika-claude"' "${ARTIFACT_DIR}/.claude-plugin/marketplace.json" || {
  echo "artifact marketplace missing monika-claude name" >&2
  exit 1
}

echo "ok"
