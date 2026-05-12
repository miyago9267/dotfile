#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
PLUGIN_NAME="monika-codex"
SOURCE_PLUGIN_DIR="${ROOT_DIR}/plugins/${PLUGIN_NAME}"
TARGET_PLUGIN_DIR="${HOME}/plugins/${PLUGIN_NAME}"
MARKETPLACE_DIR="${HOME}/.agents/plugins"
MARKETPLACE_FILE="${MARKETPLACE_DIR}/marketplace.json"

mkdir -p "${HOME}/plugins" "${MARKETPLACE_DIR}"
rm -rf "${TARGET_PLUGIN_DIR}"
cp -R "${SOURCE_PLUGIN_DIR}" "${TARGET_PLUGIN_DIR}"

python3 - "${MARKETPLACE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

marketplace_path = Path(sys.argv[1])
entry = {
    "name": "monika-codex",
    "source": {
        "source": "local",
        "path": "./plugins/monika-codex",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    },
    "category": "Productivity",
}

if marketplace_path.exists():
    data = json.loads(marketplace_path.read_text())
else:
    data = {
        "name": "miyago-local",
        "interface": {
            "displayName": "Miyago Local Plugins",
        },
        "plugins": [],
    }

plugins = [plugin for plugin in data.get("plugins", []) if plugin.get("name") != entry["name"]]
plugins.append(entry)
data["plugins"] = plugins

marketplace_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY

echo "ok"
