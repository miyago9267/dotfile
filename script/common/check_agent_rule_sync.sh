#!/bin/bash
# Verify that runtime adapters retain the canonical shared contract anchors.

set -euo pipefail

dotfile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_file="$dotfile_dir/config/ai/AGENTS.md"
personal_model_file="$dotfile_dir/../Project/AI/agent-workspace/personal-model/PROFILE.md"
codex_active_file="$dotfile_dir/config/ai/generated/codex/AGENTS.md"
claude_active_file="$dotfile_dir/config/ai/generated/claude/AGENTS.md"
gemini_active_file="$dotfile_dir/config/ai/generated/gemini/GEMINI.md"
grok_active_file="$dotfile_dir/config/ai/generated/grok/AGENTS.md"
astra_active_file="$dotfile_dir/config/ai/generated/astra/AGENTS.md"
claude_settings_file="$dotfile_dir/config/ai/claude/settings.json"
claude_file="$dotfile_dir/config/ai/claude/CLAUDE.md"
grok_file="$dotfile_dir/config/ai/grok/AGENTS.md"
pilotfish_dir="$dotfile_dir/plugins/pilotfish-grok"

test -s "$source_file"
test -s "$personal_model_file"
test -s "$codex_active_file"
test -s "$claude_active_file"
test -s "$gemini_active_file"
test -s "$grok_active_file"
test -s "$astra_active_file"

language_files=(
  "$source_file"
  "$dotfile_dir/config/ai/codex/AGENTS.md"
  "$claude_file"
  "$dotfile_dir/config/ai/gemini/GEMINI.md"
  "$grok_file"
  "$dotfile_dir/config/ai/astra/AGENTS.md"
  "$dotfile_dir/config/ai/codex/skills/human-voice/SKILL.md"
  "$dotfile_dir/config/ai/claude/skills/human-voice/SKILL.md"
)
for language_file in "${language_files[@]}"; do
  if ! grep -Fq '繁體中文' "$language_file"; then
    printf '%s\n' "Traditional Chinese policy anchor missing: $language_file" >&2
    exit 1
  fi
done
for anchor in \
  '## 語言政策' \
  '預設使用台灣繁體中文' \
  '平實用語規則' \
  '完成宣告規則' \
  '語言政策'; do
  grep -Fq "$anchor" "$source_file"
done
grep -Fq 'User-facing output 預設使用台灣繁體中文' "$dotfile_dir/config/ai/codex/AGENTS.md"
grep -Fq 'User-facing output 預設使用台灣繁體中文' "$dotfile_dir/config/ai/claude/CLAUDE.md"
grep -Fq 'User-facing output 預設使用台灣繁體中文' "$dotfile_dir/config/ai/gemini/GEMINI.md"
grep -Fq 'user-facing prose 預設使用台灣繁體中文' "$grok_file"
grep -Fq 'Astra 是唯一 identity' "$dotfile_dir/config/ai/astra/AGENTS.md"
grep -Fq '預設使用台灣繁體中文' "$dotfile_dir/config/ai/codex/skills/human-voice/SKILL.md"
grep -Fq '預設使用台灣繁體中文' "$dotfile_dir/config/ai/claude/skills/human-voice/SKILL.md"
grep -Fq '完成宣告規則' "$dotfile_dir/config/ai/codex/skills/human-voice/SKILL.md"
grep -Fq '完成宣告規則' "$dotfile_dir/config/ai/claude/skills/human-voice/SKILL.md"

if jq -e '
  ((.enabledPlugins // {}) | has("dev-discipline@dev-discipline")) or
  ((.extraKnownMarketplaces // {}) | has("dev-discipline"))
' "$claude_settings_file" >/dev/null; then
  printf '%s\n' 'dev-discipline must remain detached from Claude runtime settings' >&2
  exit 1
fi
shared_line_count=$(wc -l < "$source_file" | tr -d ' ')
if ! cmp -s <(head -n "$shared_line_count" "$codex_active_file") "$source_file"; then
  printf '%s\n' 'Codex composed rules do not start with canonical shared rules' >&2
  exit 1
fi
if ! cmp -s <(head -n "$shared_line_count" "$claude_active_file") "$source_file"; then
  printf '%s\n' 'Claude composed rules do not start with canonical shared rules' >&2
  exit 1
fi
if ! cmp -s <(head -n "$shared_line_count" "$gemini_active_file") "$source_file"; then
  printf '%s\n' 'Gemini composed rules do not start with canonical shared rules' >&2
  exit 1
fi
if ! cmp -s <(head -n "$shared_line_count" "$grok_active_file") "$source_file"; then
  printf '%s\n' 'Grok composed rules do not start with canonical shared rules' >&2
  exit 1
fi
if ! cmp -s <(head -n "$shared_line_count" "$astra_active_file") "$source_file"; then
  printf '%s\n' 'Astra composed rules do not start with canonical shared rules' >&2
  exit 1
fi

for opencode_config in \
  "$dotfile_dir/config/opencode/opencode.json" \
  "$dotfile_dir/config/opencode-studio/opencode.json" \
  "$dotfile_dir/config/opencode-harness/opencode.json"; do
  grep -Fq '~/.config/miyago-agent/AGENTS.md' "$opencode_config"
  grep -Fq '~/.config/miyago-agent/personal-model/PROFILE.md' "$opencode_config"
done
test -L "${XDG_CONFIG_HOME:-$HOME/.config}/miyago-agent/AGENTS.md"
test -L "${XDG_CONFIG_HOME:-$HOME/.config}/miyago-agent/personal-model/PROFILE.md"
test -s "${XDG_CONFIG_HOME:-$HOME/.config}/miyago-agent/AGENTS.md"
test -s "${XDG_CONFIG_HOME:-$HOME/.config}/miyago-agent/personal-model/PROFILE.md"

for active_file in "$claude_active_file" "$codex_active_file" "$gemini_active_file" "$grok_active_file" "$astra_active_file"; do
  grep -Fq 'Miyago Personal Model' "$active_file"
  grep -Fq '<!-- miyago-personal-model:begin -->' "$active_file"
  grep -Fq '<!-- miyago-personal-model:end -->' "$active_file"
  if ! cmp -s \
    <(awk 'NR == 1 && $0 == "---" { frontmatter = 1; next } frontmatter && $0 == "---" { frontmatter = 0; next } !frontmatter { print }' "$personal_model_file" | sed '/^[[:space:]]*$/d') \
    <(awk '/<!-- miyago-personal-model:begin -->/{inside=1; next} /<!-- miyago-personal-model:end -->/{inside=0} inside {print}' "$active_file" | sed '/^[[:space:]]*$/d'); then
    printf '%s\n' "Personal Model is stale in generated entry: $active_file" >&2
    exit 1
  fi
done
while IFS= read -r skill_file; do
  case "$skill_file" in
    "$dotfile_dir/config/ai/claude/skills/safe-ops/SKILL.md"|"$dotfile_dir/config/ai/gemini/skills/safe-ops/SKILL.md"|"$dotfile_dir/config/ai/astra/skills/safe-ops/SKILL.md") ;;
    *)
      printf '%s\n' "unexpected alwaysApply skill: $skill_file" >&2
      exit 1
      ;;
  esac
done < <(rg -l '^alwaysApply: true$' \
  "$dotfile_dir/config/ai/claude/skills" \
  "$dotfile_dir/config/ai/codex/skills" \
  "$dotfile_dir/config/ai/gemini/skills" \
  "$dotfile_dir/config/ai/astra/skills" 2>/dev/null || true)

for skill_name in safe-ops tdd diagnose architecture-review reverse-skill-router final-state-publication; do
  grep -Fxq "$skill_name" "$dotfile_dir/config/ai/astra/skills-allowlist.txt"
done
test -x "$dotfile_dir/script/common/setup_astra.sh"
grep -Fq 'canonical_name: Astra' "$dotfile_dir/config/ai/AGENT-ENTRY.md"
grep -Fq 'canonical_name: Astra' "$dotfile_dir/config/ai/runtime-bindings.yaml"
grep -Fq 'gpt-6-astra' "$dotfile_dir/config/ai/astra/AGENTS.md"
test -L "$HOME/.codex/skills/knowledge-base-router"
test -f "$HOME/.codex/skills/knowledge-base-router/SKILL.md"
test -L "$HOME/.codex/hooks/experience-observe.py" || {
  echo "Codex experience hook is not linked" >&2
  exit 1
}
test -x "$HOME/.codex/hooks/experience-observe.py" || {
  echo "Codex experience hook is not executable" >&2
  exit 1
}
if [ -e "$HOME/.codex/hooks/context-route.py" ]; then
  echo "Codex context route hook must remain inactive" >&2
  exit 1
fi
test -f "$HOME/.codex/hooks.json" || {
  echo "Codex hooks.json is missing" >&2
  exit 1
}
jq -e --arg command "$HOME/.codex/hooks/experience-observe.py" \
  'any(.hooks.UserPromptSubmit[]?.hooks[]?; .command == $command)' \
  "$HOME/.codex/hooks.json" >/dev/null || {
  echo "Codex experience hook is not enabled in hooks.json" >&2
  exit 1
}
grep -Fq '@AGENTS.md' "$claude_file"
grep -Fq 'rules come from `config/ai/AGENTS.md`' "$grok_file"
test "$(cat "$pilotfish_dir/VERSION")" = "1.0.6"
test -f "$pilotfish_dir/install/AGENT-INSTALL.md"
test -f "$pilotfish_dir/templates/rules.pilotfish-grok.md"
test -f "$pilotfish_dir/templates/agents/verifier.md"
test -f "$pilotfish_dir/templates/roles/verifier.toml"
grep -Fq '<!-- pilotfish-grok v1.0.6 -->' "$pilotfish_dir/templates/rules.pilotfish-grok.md"

for root_adapter in "$source_file" "$grok_file"; do
  if grep -Eq 'For material plans|Route material work|Missing roles, hooks|Preserve Pilotfish' "$root_adapter"; then
    printf '%s\n' "Pilotfish policy leaked into root adapter: $root_adapter" >&2
    exit 1
  fi
done

if rg -n 'config/ai/codex/AGENT_RULES_SHARED\.md' \
  "$dotfile_dir/config/ai/claude/CLAUDE.md" \
  "$dotfile_dir/config/ai/codex/AGENTS.md" \
  "$dotfile_dir/config/ai/grok/AGENTS.md" >/dev/null; then
  printf '%s\n' 'Codex-owned shared contract reference remains' >&2
  exit 1
fi

for anchor in \
  'Fact-check' \
  'goal -> in-scope -> stop condition' \
  'Completion claim gate' \
  'Do not call work complete while any in-scope action'; do
  grep -Fq "$anchor" "$source_file"
done

for anchor in \
  'Completion claim gate' \
  '完成但尚未驗證'; do
  grep -Fq "$anchor" "$dotfile_dir/config/ai/claude/hooks/persona-reminder.sh"
done
grep -Fq 'Apply the shared completion claim gate' "$codex_active_file"

for anchor in \
  'Runtime integration' \
  'rules come from `config/ai/AGENTS.md`'; do
  grep -Fq "$anchor" "$grok_file"
done

printf '%s\n' 'agent rule sync: OK'
