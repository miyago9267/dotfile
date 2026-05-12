#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cat "${SCRIPT_DIR}/../templates/AGENTS.md"
