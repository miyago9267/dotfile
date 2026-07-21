#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_DIR="$ROOT/config/ai/codex"
HUMAN_VOICE_SRC="$CODEX_DIR/skills/human-voice/SKILL.md"
HUMAN_VOICE_DST="$HOME/.codex/skills/human-voice"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

check_human_voice_skill() {
  [ -f "$HUMAN_VOICE_SRC" ] || fail "$HUMAN_VOICE_SRC missing"
  grep -q 'runtime-scope: codex-native' "$HUMAN_VOICE_SRC" || fail "human-voice is not Codex-native"
  grep -q 'Baseline compact' "$HUMAN_VOICE_SRC" || fail "human-voice missing compact mode"
  grep -q 'Procedural rich' "$HUMAN_VOICE_SRC" || fail "human-voice missing procedural mode"
  grep -q 'Substantial-work rich' "$HUMAN_VOICE_SRC" || fail "human-voice missing substantial-work mode"
  grep -q 'Safety-rich' "$HUMAN_VOICE_SRC" || fail "human-voice missing safety mode"
  grep -q 'Recap fallback' "$HUMAN_VOICE_SRC" || fail "human-voice missing recap fallback"
  grep -q 'ayghri/i-have-adhd' "$HUMAN_VOICE_SRC" && fail "human-voice references upstream humanizer"

  [ -L "$HUMAN_VOICE_DST" ] || fail "$HUMAN_VOICE_DST is not a symlink"
  case "$(readlink "$HUMAN_VOICE_DST")" in
    "$CODEX_DIR/skills/human-voice"|"$CODEX_DIR/skills/human-voice/") ;;
    *) fail "$HUMAN_VOICE_DST points outside repository source" ;;
  esac
}

check_human_voice_skill

check_light_profile() {
  local profile="$1"
  local file="$CODEX_DIR/$profile.config.toml"

  [ -f "$file" ] || fail "$file missing"
  if grep -q '^\[mcp_servers' "$file"; then
    fail "$profile defines mcp_servers"
  fi
  if grep -A1 '^\[plugins\."computer-use@openai-bundled"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables computer-use plugin"
  fi
  if grep -A1 '^\[plugins\."browser@openai-bundled"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables browser plugin"
  fi
  if grep -A1 '^\[plugins\."documents@openai-primary-runtime"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables documents plugin"
  fi
  if grep -A1 '^\[plugins\."spreadsheets@openai-primary-runtime"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables spreadsheets plugin"
  fi
  if grep -A1 '^\[plugins\."presentations@openai-primary-runtime"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables presentations plugin"
  fi
}

check_light_profile fast
check_light_profile code

codex exec --ignore-user-config -p fast --strict-config --version >/dev/null
codex exec --ignore-user-config -p code --strict-config --version >/dev/null
codex exec -p heavy --strict-config --version >/dev/null

printf 'OK: codex profiles pass hygiene checks\n'
