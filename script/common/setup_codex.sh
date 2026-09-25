#!/bin/bash
# Codex CLI 全域設定 symlink 建立腳本
# 將 dotfile/config/ai/codex/ 下的設定 symlink 回 native Codex 與 Orca runtime
# 安裝 shared-core skills + Codex native skills，避免整包混入 Claude runtime skills

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_SRC="$DOTFILE_DIR/config/ai/codex"
CODEX_MODEL_DEFAULTS="$CODEX_SRC/model-defaults.toml"
CODEX_MODEL_SYNC="$DOTFILE_DIR/script/common/codex_model_defaults.py"
CODEX_DST="$HOME/.codex"
ORCA_CODEX_RUNTIME_HOME="${ORCA_CODEX_RUNTIME_HOME:-$HOME/Library/Application Support/orca/codex-runtime-home/home}"
CODEX_SKILL_SRC="$DOTFILE_DIR/config/ai/codex/skills"
CODEX_HOOK_SRC="$DOTFILE_DIR/config/ai/codex/hooks/experience-observe.py"
CODEX_HOOK_DST="$HOME/.codex/hooks/experience-observe.py"
FACTORY_SESSION_SRC="$DOTFILE_DIR/config/ai/shared/hooks/factory-session-start.py"
FACTORY_SESSION_DST="$HOME/.codex/hooks/factory-session-start.py"
COMPACTION_SHADOW_SRC="$DOTFILE_DIR/config/ai/shared/jev/compaction-shadow.py"
COMPACTION_SHADOW_DST="$HOME/.codex/hooks/jev-compaction-shadow.py"
SHARED_SKILL_SRC="$DOTFILE_DIR/config/ai/shared/skills"
SHARED_RULES_SRC="$DOTFILE_DIR/config/ai/AGENTS.md"
PERSONAL_MODEL_SRC="${PERSONAL_MODEL_SRC:-$DOTFILE_DIR/../Project/AI/agent-workspace/personal-model/PROFILE.md}"
SHARED_MEMORY_SRC="$DOTFILE_DIR/config/ai/memories"
ACTIVE_RULES_DIR="$DOTFILE_DIR/config/ai/generated/codex"
ACTIVE_RULES_SRC="$ACTIVE_RULES_DIR/AGENTS.md"

Y='\033[1;33m'
G='\033[1;32m'
R='\033[1;31m'
N='\033[0m'

link_item() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -e "$src" ]; then
    printf "${R}  [SKIP] %s -- source missing${N}\n" "$label"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf "${G}  [OK]   %s${N}\n" "$label"
    return
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    printf "${Y}  [BAK]  %s -> %s${N}\n" "$label" "$backup"
    mv "$dst" "$backup"
  elif [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  ln -s "$src" "$dst"
  printf "${G}  [LINK] %s${N}\n" "$label"
}

sync_model_defaults() {
  local config_path="$1"
  if [ ! -f "$CODEX_MODEL_DEFAULTS" ] || [ ! -f "$CODEX_MODEL_SYNC" ]; then
    printf "${Y}  [SKIP] model defaults -- source missing${N}\n"
    return
  fi
  python3 "$CODEX_MODEL_SYNC" "$config_path" "$CODEX_MODEL_DEFAULTS"
}

normalize_git_url() {
  printf '%s\n' "$1" | sed -E \
    -e 's#^git@([^:]+):#\1/#' \
    -e 's#^ssh://git@##' \
    -e 's#^https?://##' \
    -e 's#\.git/?$##' \
    -e 's#/$##'
}

install_git_skill() {
  local name="$1"
  local repo="$2"
  local dst="$CODEX_DST/skills/$name"
  local actual_repo
  local expected_repo
  local ssh_command

  if [ -L "$dst" ]; then
    printf "${Y}  [SKIP] skills/%s -- unmanaged symlink exists${N}\n" "$name"
    return
  fi

  if [ -d "$dst/.git" ]; then
    actual_repo=$(git -C "$dst" remote get-url origin 2>/dev/null || true)
    expected_repo=$(normalize_git_url "$repo")
    if [ "$(normalize_git_url "$actual_repo")" != "$expected_repo" ]; then
      printf "${Y}  [SKIP] skills/%s -- origin mismatch${N}\n" "$name"
      return
    fi
    if [ -n "$(git -C "$dst" status --porcelain)" ]; then
      printf "${Y}  [SKIP] skills/%s -- local changes exist${N}\n" "$name"
      return
    fi
    ssh_command='ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes'
    if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="$ssh_command" \
      git -C "$dst" pull --ff-only --quiet; then
      printf "${G}  [OK]   skills/%s${N}\n" "$name"
    else
      printf "${Y}  [WARN] skills/%s -- update failed${N}\n" "$name"
    fi
    return
  fi

  if [ -e "$dst" ]; then
    printf "${Y}  [SKIP] skills/%s -- unmanaged path exists${N}\n" "$name"
    return
  fi

  ssh_command='ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes'
  if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="$ssh_command" \
    git clone --quiet "$repo" "$dst"; then
    printf "${G}  [CLONE] skills/%s${N}\n" "$name"
  else
    printf "${Y}  [SKIP] skills/%s -- private repo unavailable${N}\n" "$name"
  fi
}

install_pinned_git_skill() {
  local name="$1"
  local repo="$2"
  local commit="$3"
  local dst="$CODEX_DST/vendor/$name"
  local actual_repo

  if [ -L "$dst" ]; then
    printf "${Y}  [SKIP] vendor/%s -- unmanaged symlink exists${N}\n" "$name"
    return
  fi

  if [ -d "$dst/.git" ]; then
    actual_repo=$(git -C "$dst" remote get-url origin 2>/dev/null || true)
    if [ "$(normalize_git_url "$actual_repo")" != "$(normalize_git_url "$repo")" ]; then
      printf "${Y}  [SKIP] vendor/%s -- origin mismatch${N}\n" "$name"
      return
    fi
    if [ "$(git -C "$dst" rev-parse HEAD 2>/dev/null || true)" = "$commit" ]; then
      printf "${G}  [OK]   vendor/%s @ %s${N}\n" "$name" "${commit:0:12}"
    else
      printf "${Y}  [SKIP] vendor/%s -- pinned commit mismatch${N}\n" "$name"
    fi
    return
  fi

  if [ -e "$dst" ]; then
    printf "${Y}  [SKIP] vendor/%s -- unmanaged path exists${N}\n" "$name"
    return
  fi

  if GIT_TERMINAL_PROMPT=0 git clone --quiet "$repo" "$dst" \
    && git -C "$dst" checkout --quiet "$commit" \
    && [ "$(git -C "$dst" rev-parse HEAD)" = "$commit" ]; then
    printf "${G}  [CLONE] vendor/%s @ %s${N}\n" "$name" "${commit:0:12}"
  else
    printf "${Y}  [SKIP] vendor/%s -- pinned install failed${N}\n" "$name"
  fi
}

compose_active_rules() {
  mkdir -p "$ACTIVE_RULES_DIR"
  local tmp_file="$ACTIVE_RULES_SRC.tmp.$$"
  {
    cat "$SHARED_RULES_SRC"
    printf '\n\n<!-- miyago-personal-model:begin -->\n\n'
    if [ -f "$PERSONAL_MODEL_SRC" ]; then
      awk 'NR == 1 && $0 == "---" { frontmatter = 1; next } frontmatter && $0 == "---" { frontmatter = 0; next } !frontmatter { print }' "$PERSONAL_MODEL_SRC"
    else
      printf '%s\n' 'Personal Model unavailable; use shared contract only.' >&2
    fi
    printf '\n<!-- miyago-personal-model:end -->\n\n'
    printf '%s\n\n' '<!-- runtime-adapter:begin -->'
    cat "$CODEX_SRC/AGENTS.md"
    printf '\n%s\n' '<!-- runtime-adapter:end -->'
  } > "$tmp_file"
  mv "$tmp_file" "$ACTIVE_RULES_SRC"
}

SHARED_CORE_SKILLS=(
  knowledge-base-router
  final-state-publication
  community-tech-brief
  jev-tools
)

EXTERNAL_CODEX_SKILLS=(
  "build-install|https://github.com/miyago9267/build-install.git"
)

PINNED_EXTERNAL_CODEX_SKILLS=(
  "reverse-skill-pack|https://github.com/zhaoxuya520/reverse-skill.git|914f74ad7d42d18d983d5842f8156440d9068399"
)

printf "${Y}=== Codex CLI 設定 Symlink ===${N}\n"

mkdir -p "$CODEX_DST" "$CODEX_DST/skills" "$CODEX_DST/vendor"
sync_model_defaults "$CODEX_DST/config.toml"
mkdir -p "$HOME/bin"

compose_active_rules
link_item "$ACTIVE_RULES_SRC" "$CODEX_DST/AGENTS.md" "AGENTS.md"
link_item "$SHARED_RULES_SRC" "$CODEX_DST/AGENTS.shared.md" "shared agent contract"
if [ -d "$(dirname "$ORCA_CODEX_RUNTIME_HOME")" ]; then
  mkdir -p "$ORCA_CODEX_RUNTIME_HOME"
  sync_model_defaults "$ORCA_CODEX_RUNTIME_HOME/config.toml"
  link_item "$ACTIVE_RULES_SRC" "$ORCA_CODEX_RUNTIME_HOME/AGENTS.md" "Orca Codex AGENTS.md"
  link_item "$SHARED_RULES_SRC" "$ORCA_CODEX_RUNTIME_HOME/AGENTS.shared.md" "Orca Codex shared agent contract"
fi
link_item "$SHARED_MEMORY_SRC" "$CODEX_DST/memories" "shared memories"
mkdir -p "$CODEX_DST/hooks"
chmod 755 "$CODEX_HOOK_SRC"
link_item "$CODEX_HOOK_SRC" "$CODEX_HOOK_DST" "hooks/experience-observe.py"
chmod 755 "$FACTORY_SESSION_SRC"
link_item "$FACTORY_SESSION_SRC" "$FACTORY_SESSION_DST" "hooks/factory-session-start.py"

ensure_factory_session_hook() {
  local hooks_file="$CODEX_DST/hooks.json"
  local tmp_file
  [ -f "$hooks_file" ] || return
  command -v jq >/dev/null 2>&1 || return
  tmp_file="$hooks_file.tmp.$$"
  if jq --arg command "$FACTORY_SESSION_DST" '
    .hooks //= {}
    | .hooks.UserPromptSubmit //= []
    | if any(.hooks.UserPromptSubmit[]?.hooks[]?; .command == $command)
      then .
      else .hooks.UserPromptSubmit += [{hooks: [{type: "command", command: $command, timeout: 8}]}]
      end
  ' "$hooks_file" > "$tmp_file"; then
    mv "$tmp_file" "$hooks_file"
    printf "${G}  [OK]   hooks.json -- Factory session-start enabled${N}\n"
  else
    rm -f "$tmp_file"
    printf "${Y}  [SKIP] hooks.json -- cannot add Factory session-start${N}\n"
  fi
}

ensure_factory_session_hook

ensure_experience_hook() {
  local hooks_file="$CODEX_DST/hooks.json"
  local tmp_file
  [ -f "$hooks_file" ] || {
    printf "${Y}  [SKIP] hooks.json -- existing hook configuration not found${N}\n"
    return
  }
  command -v jq >/dev/null 2>&1 || {
    printf "${Y}  [SKIP] hooks.json -- jq is unavailable${N}\n"
    return
  }
  tmp_file="$hooks_file.tmp.$$"
  if jq --arg command "$CODEX_HOOK_DST" '
    .hooks //= {}
    | .hooks.UserPromptSubmit //= []
    | if any(.hooks.UserPromptSubmit[]?.hooks[]?; .command == $command)
      then .
      else .hooks.UserPromptSubmit += [{hooks: [{type: "command", command: $command, timeout: 5}]}]
      end
  ' "$hooks_file" > "$tmp_file"; then
    mv "$tmp_file" "$hooks_file"
    printf "${G}  [OK]   hooks.json -- experience observation enabled${N}\n"
  else
    rm -f "$tmp_file"
    printf "${Y}  [SKIP] hooks.json -- invalid JSON or cannot update${N}\n"
  fi
}

ensure_experience_hook

ensure_compaction_shadow_hook() {
  local hooks_file="$CODEX_DST/hooks.json"
  local tmp_file
  chmod 755 "$COMPACTION_SHADOW_SRC"
  link_item "$COMPACTION_SHADOW_SRC" "$COMPACTION_SHADOW_DST" "hooks/jev-compaction-shadow.py"
  [ -f "$hooks_file" ] || return
  command -v jq >/dev/null 2>&1 || return
  tmp_file="$hooks_file.tmp.$$"
  if jq --arg command "$COMPACTION_SHADOW_DST" '
    .hooks //= {}
    | .hooks.PostToolUse //= []
    | if any(.hooks.PostToolUse[]?.hooks[]?; .command == $command)
      then .
      else .hooks.PostToolUse += [{hooks: [{type: "command", command: $command, timeout: 3}]}]
      end
  ' "$hooks_file" > "$tmp_file"; then
    mv "$tmp_file" "$hooks_file"
    printf "${G}[OK]   hooks.json -- Jev compaction shadow enabled${N}\n"
  else
    rm -f "$tmp_file"
    printf "${Y}[SKIP] hooks.json -- cannot add Jev compaction shadow${N}\n"
  fi
}

ensure_compaction_shadow_hook

for profile in fast code heavy; do
  link_item "$CODEX_SRC/$profile.config.toml" "$CODEX_DST/$profile.config.toml" "$profile.config.toml"
done

if [ -d "$ORCA_CODEX_RUNTIME_HOME" ]; then
  for profile in fast code heavy; do
    link_item "$CODEX_SRC/$profile.config.toml" "$ORCA_CODEX_RUNTIME_HOME/$profile.config.toml" "Orca $profile.config.toml"
  done
fi

link_item "$CODEX_SRC/coralline" "$CODEX_DST/coralline" "coralline"
link_item "$CODEX_SRC/coralline.conf" "$CODEX_DST/coralline.conf" "coralline.conf"

printf "\n${Y}--- Shared Core Skills ---${N}\n"
for name in "${SHARED_CORE_SKILLS[@]}"; do
  if [ -f "$SHARED_SKILL_SRC/$name/SKILL.md" ]; then
    link_item "$SHARED_SKILL_SRC/$name" "$CODEX_DST/skills/$name" "skills/$name"
  fi
done

if [ -d "$CODEX_SKILL_SRC" ]; then
  printf "\n${Y}--- Codex Native Skills ---${N}\n"
  for skill_dir in "$CODEX_SKILL_SRC"/*/; do
    name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      link_item "$skill_dir" "$CODEX_DST/skills/$name" "skills/$name"
    fi
  done
fi

# Remove only managed symlinks that are no longer in the Codex skill set.
# Leave real directories and externally managed links untouched.
for skill_path in "$CODEX_DST/skills"/*; do
  [ -L "$skill_path" ] || continue
  target=$(readlink "$skill_path")
  case "$target" in
    "$DOTFILE_DIR/config/ai/shared/skills/"*|"$DOTFILE_DIR/config/ai/codex/skills/"*)
      skill_name=$(basename "$skill_path")
      keep=false
      for allowed in "${SHARED_CORE_SKILLS[@]}"; do
        [ "$skill_name" = "$allowed" ] && keep=true
      done
      if [ -d "$CODEX_SKILL_SRC/$skill_name" ]; then
        keep=true
      fi
      if [ "$keep" = false ]; then
        rm -f "$skill_path"
      fi
      ;;
  esac
done

printf '\n%b--- External Codex Skills ---%b\n' "$Y" "$N"
for entry in "${EXTERNAL_CODEX_SKILLS[@]}"; do
  IFS='|' read -r name repo <<< "$entry"
  install_git_skill "$name" "$repo"
done

printf '\n%b--- Pinned External Codex Skills ---%b\n' "$Y" "$N"
for entry in "${PINNED_EXTERNAL_CODEX_SKILLS[@]}"; do
  IFS='|' read -r name repo commit <<< "$entry"
  install_pinned_git_skill "$name" "$repo" "$commit"
done

printf "${G}=== 完成 ===${N}\n"
