#!/bin/bash
# Verify that Claude and Grok retain the Codex-sourced contract anchors.

set -euo pipefail

dotfile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_file="$dotfile_dir/config/ai/codex/AGENT_RULES_SHARED.md"
claude_file="$dotfile_dir/config/ai/claude/CLAUDE.md"
grok_file="$dotfile_dir/config/ai/grok/AGENTS.md"
pilotfish_dir="$dotfile_dir/plugins/pilotfish-grok"

test -s "$source_file"
grep -Fq '@AGENT_RULES_SHARED.md' "$claude_file"
grep -Fq 'Codex-sourced contract' "$grok_file"
test "$(cat "$pilotfish_dir/VERSION")" = "1.0.6"
test -f "$pilotfish_dir/install/AGENT-INSTALL.md"
test -f "$pilotfish_dir/templates/rules.pilotfish-grok.md"
test -f "$pilotfish_dir/templates/agents/verifier.md"
test -f "$pilotfish_dir/templates/roles/verifier.toml"
grep -Fq '<!-- pilotfish-grok v1.0.6 -->' "$pilotfish_dir/templates/rules.pilotfish-grok.md"

for root_adapter in "$dotfile_dir/config/ai/AGENTS.md" "$grok_file"; do
  if grep -Eq 'For material plans|Route material work|Missing roles, hooks|Preserve Pilotfish' "$root_adapter"; then
    printf '%s\n' "Pilotfish policy leaked into root adapter: $root_adapter" >&2
    exit 1
  fi
done

for anchor in \
  'Fact-check' \
  'goal -> in-scope -> stop condition' \
  'Children never spawn children' \
  'credential broker'; do
  grep -Fq "$anchor" "$source_file"
  grep -Fq "$anchor" "$grok_file"
done

printf '%s\n' 'agent rule sync: OK'
