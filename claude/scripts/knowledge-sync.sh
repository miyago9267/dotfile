#!/bin/bash
set -euo pipefail

# Knowledge Base Sync
# 從遠端 knowledge repo 同步知識庫到本機快取，不在每台電腦維護完整副本

# --- 設定 ---
# 預設 knowledge repo，可透過環境變數或 .knowledge-config 覆蓋
DEFAULT_KNOWLEDGE_REPO="ssh://git@git.dunqian.tw:30001/itrd/knowledge-base.git"
CACHE_DIR="${HOME}/.cache/agent-skills/knowledge"
CONFIG_FILE=".knowledge-config"
MAX_CACHE_AGE_HOURS=4

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 讀取設定 ---
resolve_repo_url() {
  # 優先順序：環境變數 > 專案 config > 全域 config > 預設值
  if [[ -n "${KNOWLEDGE_REPO:-}" ]]; then
    echo "$KNOWLEDGE_REPO"
  elif [[ -f "$CONFIG_FILE" ]]; then
    grep -m1 '^repo=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- || echo "$DEFAULT_KNOWLEDGE_REPO"
  elif [[ -f "${HOME}/.config/agent-skills/config" ]]; then
    grep -m1 '^knowledge_repo=' "${HOME}/.config/agent-skills/config" 2>/dev/null | cut -d= -f2- || echo "$DEFAULT_KNOWLEDGE_REPO"
  else
    echo "$DEFAULT_KNOWLEDGE_REPO"
  fi
}

# --- 快取是否過期 ---
cache_is_fresh() {
  local marker="${CACHE_DIR}/.last-sync"
  if [[ ! -f "$marker" ]]; then
    return 1
  fi
  local last_sync
  last_sync=$(cat "$marker")
  local now
  now=$(date +%s)
  local age=$(( (now - last_sync) / 3600 ))
  if [[ $age -lt $MAX_CACHE_AGE_HOURS ]]; then
    return 0
  fi
  return 1
}

mark_synced() {
  date +%s > "${CACHE_DIR}/.last-sync"
}

# --- 指令 ---
usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  sync              同步遠端知識庫到本機快取"
  echo "  sync --force      強制同步（忽略快取時間）"
  echo "  status            檢查快取狀態"
  echo "  search <keyword>  搜尋知識庫"
  echo "  read <path>       讀取特定知識文件"
  echo "  list [category]   列出知識文件"
  echo "  link <target>     建立 symlink 到專案目錄"
  echo ""
  echo "Environment:"
  echo "  KNOWLEDGE_REPO    覆蓋預設 repo URL"
  echo "  KNOWLEDGE_CACHE   覆蓋快取目錄（預設 ~/.cache/agent-skills/knowledge）"
}

cmd_sync() {
  local force="${1:-}"
  local repo_url
  repo_url=$(resolve_repo_url)

  if [[ "$force" != "--force" ]] && cache_is_fresh; then
    info "快取仍有效（${MAX_CACHE_AGE_HOURS}h 內），跳過同步。用 --force 強制更新"
    return 0
  fi

  info "同步知識庫: ${repo_url}"

  if [[ -d "${CACHE_DIR}/.git" ]]; then
    # 已有本機快取，pull 更新
    git -C "$CACHE_DIR" fetch --depth=1 origin main 2>/dev/null && \
    git -C "$CACHE_DIR" reset --hard origin/main 2>/dev/null
    ok "已更新"
  else
    # 首次 clone（shallow）
    mkdir -p "$(dirname "$CACHE_DIR")"
    git clone --depth=1 "$repo_url" "$CACHE_DIR" 2>/dev/null
    ok "首次下載完成"
  fi

  mark_synced
  info "快取位置: ${CACHE_DIR}"
}

cmd_status() {
  echo ""
  echo "=== Knowledge Base Status ==="
  local repo_url
  repo_url=$(resolve_repo_url)
  echo "  Repo:   ${repo_url}"
  echo "  Cache:  ${CACHE_DIR}"

  if [[ -d "${CACHE_DIR}/.git" ]]; then
    local last_sync_file="${CACHE_DIR}/.last-sync"
    if [[ -f "$last_sync_file" ]]; then
      local ts
      ts=$(cat "$last_sync_file")
      local last_sync_human
      last_sync_human=$(date -r "$ts" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
      echo "  Synced: ${last_sync_human}"
      if cache_is_fresh; then
        echo -e "  Status: ${GREEN}fresh${NC}"
      else
        echo -e "  Status: ${YELLOW}stale (> ${MAX_CACHE_AGE_HOURS}h)${NC}"
      fi
    fi
    local count
    count=$(find "$CACHE_DIR" -name "*.md" -not -path "*/.git/*" | wc -l | tr -d ' ')
    echo "  Files:  ${count} markdown files"
  else
    echo -e "  Status: ${RED}not synced${NC}"
    echo "  Run: $0 sync"
  fi
  echo ""
}

cmd_search() {
  local keyword="${1:-}"
  if [[ -z "$keyword" ]]; then
    err "用法: $0 search <keyword>"
    exit 1
  fi

  if [[ ! -d "$CACHE_DIR" ]]; then
    err "知識庫尚未同步。先執行: $0 sync"
    exit 1
  fi

  # 先確認快取是否需要更新
  if ! cache_is_fresh; then
    warn "快取已過期，建議執行 sync"
  fi

  grep -rl --include="*.md" -i "$keyword" "$CACHE_DIR" 2>/dev/null | \
    sed "s|${CACHE_DIR}/||" | \
    grep -v "^\.git" || \
    echo "沒有找到符合 '${keyword}' 的文件"
}

cmd_read() {
  local filepath="${1:-}"
  if [[ -z "$filepath" ]]; then
    err "用法: $0 read <path>"
    exit 1
  fi

  local full_path="${CACHE_DIR}/${filepath}"
  if [[ -f "$full_path" ]]; then
    cat "$full_path"
  else
    err "找不到: ${filepath}"
    echo "用 '$0 list' 查看可用文件"
    exit 1
  fi
}

cmd_list() {
  local category="${1:-}"

  if [[ ! -d "$CACHE_DIR" ]]; then
    err "知識庫尚未同步。先執行: $0 sync"
    exit 1
  fi

  local search_dir="$CACHE_DIR"
  if [[ -n "$category" ]]; then
    search_dir="${CACHE_DIR}/${category}"
    if [[ ! -d "$search_dir" ]]; then
      err "分類不存在: ${category}"
      echo "可用分類: $(ls -d "${CACHE_DIR}"/*/ 2>/dev/null | xargs -n1 basename | grep -v '\.git' | tr '\n' ', ' | sed 's/,$//')"
      exit 1
    fi
  fi

  find "$search_dir" -name "*.md" -not -path "*/.git/*" -not -name "README.md" | \
    sed "s|${CACHE_DIR}/||" | \
    sort || \
    echo "（空）"
}

cmd_link() {
  local target="${1:-.claude/knowledge}"

  if [[ ! -d "$CACHE_DIR" ]]; then
    err "知識庫尚未同步。先執行: $0 sync"
    exit 1
  fi

  # 確保快取是最新的
  cmd_sync

  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" ]]; then
    rm "$target"
  elif [[ -d "$target" ]]; then
    warn "${target} 已存在且不是 symlink，跳過"
    return 1
  fi

  ln -s "$CACHE_DIR" "$target"
  ok "已建立 symlink: ${target} -> ${CACHE_DIR}"
}

# --- Main ---
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  sync)    cmd_sync "${1:-}" ;;
  status)  cmd_status ;;
  search)  cmd_search "${1:-}" ;;
  read)    cmd_read "${1:-}" ;;
  list)    cmd_list "${1:-}" ;;
  link)    cmd_link "${1:-}" ;;
  *)       usage ;;
esac
