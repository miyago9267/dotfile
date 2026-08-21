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
claude_file="$dotfile_dir/config/ai/claude/CLAUDE.md"
grok_file="$dotfile_dir/config/ai/grok/AGENTS.md"
pilotfish_dir="$dotfile_dir/plugins/pilotfish-grok"

test -s "$source_file"
test -s "$personal_model_file"
test -s "$codex_active_file"
test -s "$claude_active_file"
test -s "$gemini_active_file"
test -s "$grok_active_file"
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

for active_file in "$claude_active_file" "$codex_active_file" "$gemini_active_file" "$grok_active_file"; do
  grep -Fq 'miyago-context-harness' "$active_file"
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
test -L "$HOME/.codex/hooks/experience-observe.py" || {
  echo "Codex experience hook is not linked" >&2
  exit 1
}
test -x "$HOME/.codex/hooks/experience-observe.py" || {
  echo "Codex experience hook is not executable" >&2
  exit 1
}
test -L "$HOME/.codex/hooks/context-route.py" || {
  echo "Codex context route hook is not linked" >&2
  exit 1
}
test -x "$HOME/.codex/hooks/context-route.py" || {
  echo "Codex context route hook is not executable" >&2
  exit 1
}
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
grep -Fq 'Shared contract source' "$grok_file"
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
  'goal -> in-scope -> stop condition'; do
  grep -Fq "$anchor" "$source_file"
done

for anchor in \
  'Children never spawn children' \
  'credential broker'; do
  grep -Fq "$anchor" "$grok_file"
done

printf '%s\n' 'agent rule sync: OK'
