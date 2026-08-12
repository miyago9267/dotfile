#!/bin/bash
# Codex CLI 全域設定 symlink 建立腳本
# 將 dotfile/config/ai/codex/ 下的設定 symlink 回 ~/.codex/
# 安裝 shared-core skills + Codex native skills，避免整包混入 Claude runtime skills

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_SRC="$DOTFILE_DIR/config/ai/codex"
CODEX_DST="$HOME/.codex"
SHARED_SKILL_SRC="$DOTFILE_DIR/config/ai/claude/skills"
CODEX_SKILL_SRC="$DOTFILE_DIR/config/ai/codex/skills"

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

SHARED_CORE_SKILLS=(
  ask-discipline
  git-workflow
  no-ai-attribution
  path-aware
  safe-ops
  search-discipline
)

EXTERNAL_CODEX_SKILLS=(
  "knowledge-base-router|git@github.com:miyago9267/knowledge-base-router.git"
  "build-install|https://github.com/miyago9267/build-install.git"
)

printf "${Y}=== Codex CLI 設定 Symlink ===${N}\n"

mkdir -p "$CODEX_DST" "$CODEX_DST/skills"

link_item "$CODEX_SRC/AGENTS.md" "$CODEX_DST/AGENTS.md" "AGENTS.md"

for profile in fast code heavy; do
  link_item "$CODEX_SRC/$profile.config.toml" "$CODEX_DST/$profile.config.toml" "$profile.config.toml"
done

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
    "$DOTFILE_DIR/config/ai/claude/skills/"*|"$DOTFILE_DIR/config/ai/codex/skills/"*)
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

printf "${G}=== 完成 ===${N}\n"
