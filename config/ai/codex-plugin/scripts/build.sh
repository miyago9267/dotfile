#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
PLUGIN_SOURCE_DIR="${ROOT_DIR}/config/ai/codex-plugin"
PLUGIN_DIR="${ROOT_DIR}/plugins/monika-codex"
MARKETPLACE_DIR="${ROOT_DIR}/.agents/plugins"
ALLOWLIST_FILE="${PLUGIN_SOURCE_DIR}/skills-allowlist.txt"
copy_skill() {
  local skill_name="$1"
  local source_dir=""

  for candidate in \
    "${ROOT_DIR}/config/ai/codex/skills/${skill_name}" \
    "${ROOT_DIR}/config/ai/astra/skills/${skill_name}" \
    "${ROOT_DIR}/config/ai/claude/skills/${skill_name}" \
    "${ROOT_DIR}/config/ai/gemini/skills/${skill_name}"; do
    if [[ -d "${candidate}" ]]; then
      source_dir="${candidate}"
      break
    fi
  done

  if [[ -z "${source_dir}" ]]; then
    echo "missing skill source: ${skill_name}" >&2
    exit 1
  fi

  cp -R "${source_dir}" "${PLUGIN_DIR}/skills/${skill_name}"
}

compose_agents() {
  local output_file="$1"

  {
    cat "${ROOT_DIR}/config/ai/AGENTS.md"
    echo ""
    echo "---"
    echo ""
    cat "${ROOT_DIR}/config/ai/codex/AGENTS.md"
  } > "${output_file}"
}

merge_marketplace() {
  ruby -rjson - "${MARKETPLACE_DIR}/marketplace.json" "${PLUGIN_SOURCE_DIR}/marketplace.json" <<'RUBY'
target_path, source_path = ARGV
source = JSON.parse(File.read(source_path))
target = File.exist?(target_path) ? JSON.parse(File.read(target_path)) : source.dup
target["plugins"] ||= []
entry = source.fetch("plugins").find { |plugin| plugin["name"] == "monika-codex" }
raise "marketplace source missing monika-codex" unless entry

index = target["plugins"].index { |plugin| plugin["name"] == entry["name"] }
if index
  target["plugins"][index] = entry
else
  target["plugins"] << entry
end

File.write(target_path, JSON.pretty_generate(target) + "\n")
RUBY
}

rm -rf "${PLUGIN_DIR}"
mkdir -p \
  "${PLUGIN_DIR}/.codex-plugin" \
  "${PLUGIN_DIR}/skills" \
  "${PLUGIN_DIR}/templates" \
  "${PLUGIN_DIR}/scripts" \
  "${MARKETPLACE_DIR}"

cp "${PLUGIN_SOURCE_DIR}/plugin.json" "${PLUGIN_DIR}/.codex-plugin/plugin.json"
merge_marketplace

while IFS= read -r skill_name; do
  [[ -z "${skill_name}" ]] && continue
  copy_skill "${skill_name}"
done < "${ALLOWLIST_FILE}"

compose_agents "${PLUGIN_DIR}/templates/AGENTS.md"
cp "${ROOT_DIR}/docs/specs/_templates/"*.template.md "${PLUGIN_DIR}/templates/"
cp "${PLUGIN_SOURCE_DIR}/runtime/"*.sh "${PLUGIN_DIR}/scripts/"
chmod +x "${PLUGIN_DIR}/scripts/"*.sh

cat > "${PLUGIN_DIR}/README.md" <<'EOF'
# monika-codex

Codex plugin artifact for Miyago's Monika workflow.

## Includes

- composed `AGENTS.md` template from shared contract + Codex adapter
- spec templates for `docs/specs/_templates/`
- curated workflow skills for Codex
- helper scripts to export or initialize project rules

## Rebuild from source

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/codex-plugin/scripts/build.sh
```

## Validate

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/codex-plugin/scripts/validate.sh
```

## Project bootstrap

```bash
source ~/.zshrc 2>/dev/null
bash plugins/monika-codex/scripts/project-init.sh /path/to/project
```
EOF
