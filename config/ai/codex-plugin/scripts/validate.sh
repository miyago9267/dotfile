#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
PLUGIN_DIR="${ROOT_DIR}/plugins/monika-codex"
MARKETPLACE_FILE="${ROOT_DIR}/.agents/plugins/marketplace.json"

required_files=(
  "${PLUGIN_DIR}/.codex-plugin/plugin.json"
  "${PLUGIN_DIR}/README.md"
  "${PLUGIN_DIR}/templates/AGENTS.md"
  "${PLUGIN_DIR}/templates/SPEC.template.md"
  "${PLUGIN_DIR}/templates/TASKS.template.md"
  "${PLUGIN_DIR}/templates/TESTS.template.md"
  "${PLUGIN_DIR}/templates/PROGRESS.template.md"
  "${PLUGIN_DIR}/scripts/export-agents.sh"
  "${PLUGIN_DIR}/scripts/project-init.sh"
  "${MARKETPLACE_FILE}"
)

for file in "${required_files[@]}"; do
  [[ -f "${file}" ]] || {
    echo "missing required file: ${file}" >&2
    exit 1
  }
done

[[ -d "${PLUGIN_DIR}/skills" ]] || {
  echo "missing skills directory" >&2
  exit 1
}

grep -q '"name": "monika-codex"' "${PLUGIN_DIR}/.codex-plugin/plugin.json" || {
  echo "plugin manifest missing monika-codex name" >&2
  exit 1
}

grep -q '"path": "./plugins/monika-codex"' "${MARKETPLACE_FILE}" || {
  echo "marketplace missing monika-codex path" >&2
  exit 1
}

echo "ok"
