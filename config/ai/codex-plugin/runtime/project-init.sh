#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"

mkdir -p "${TARGET_DIR}/docs/specs/_templates"

cp "${SCRIPT_DIR}/../templates/AGENTS.md" "${TARGET_DIR}/AGENTS.md"
cp "${SCRIPT_DIR}/../templates/"*.template.md "${TARGET_DIR}/docs/specs/_templates/"

echo "ok"
