#!/bin/bash
# Miyago Dotfile 開發環境 playbook
# 使用方式：bash setup.sh [--environment|--all|--everything|--config-only|--help]
#   --environment 只顯示環境安裝項目
#   --all         安裝所有非 optional 項目
#   --everything  安裝包含 optional 項目的全部項目
#   --config-only 只同步 dotfiles、AI runtime 設定與 symlink

set -eo pipefail

# -- 色彩 --
Y='\033[1;33m'
G='\033[1;32m'
C='\033[1;36m'
R='\033[1;31m'
B='\033[1m'
N='\033[0m'

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$DIR/script/common"
LINUX_DIR="$DIR/script/linux"
ERROR_LOG="$DIR/error.log"
CURRENT_RUN_LOG=""

# -- 平台偵測 --
. "$SCRIPT_DIR/_platform.sh"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'HELP'
Usage: bash setup.sh [--environment|--all|--everything|--config-only|--help]

  (default)       Interactive config selection (environment items visible)
  --environment   Interactive environment-install selection only
  --all           Run every non-optional platform-supported item
  --everything    Run every platform-supported item, including optional mobile tools
  --config-only   Sync repository-managed config and runtime symlinks only
  --help          Show this help

Interactive keys:
  Space          Toggle item
  Ctrl-A / Ctrl-N Select all / clear all
  Enter          Apply selection
  Esc            Cancel
HELP
  exit 0
fi

# -- 安裝項目定義 --
# 格式：腳本檔名|顯示名稱|分類|config預設|environment預設|模式|平台標籤|optional
_ALL_ITEMS=(
  "dependencis.sh|基礎依賴套件 (Homebrew 等)|基礎|0|1|environment|all|0"
  "setup_dotfiles.sh|Dotfiles 連結 (symlink)|基礎|1|0|config|all|0"
  "setup_zsh.sh|Zsh / Zplug 環境|Shell|0|1|environment|darwin linux|0"
  "setup_vim.sh|Vim 設定|編輯器|1|0|config|all|0"
  "setup_neovim.sh|Neovim 環境與設定|編輯器|0|1|environment|darwin linux:apt linux:pacman|0"
  "setup_tmux.sh|Tmux 環境與設定|終端|0|1|environment|darwin linux:apt linux:pacman|0"
  "setup_fonts.sh|字型安裝|基礎|0|0|environment|all|0"
  "setup_claude.sh|Claude Code 設定 (symlink)|工具|1|0|config|all|0"
  "setup_codex.sh|Codex CLI 設定 (symlink)|工具|1|0|config|all|0"
  "setup_gemini.sh|Gemini CLI 設定 (symlink)|工具|1|0|config|all|0"
  "install_claude.sh|Claude Code CLI|工具|0|0|environment|all|0"
  "install_gemini.sh|Gemini CLI (official npm)|工具|0|0|environment|darwin linux|0"
  "install_codex.sh|Codex CLI (official installer)|工具|0|0|environment|darwin linux|0"
  "install_sesh.sh|sesh (跨 CC/codex session finder)|工具|0|0|environment|darwin linux:apt linux:pacman|0"
  "install_gh.sh|Git CLI 工具 (gh + glab)|工具|0|0|environment|darwin linux:apt linux:pacman|0"
  "install_remora_proxy.sh|Remora + Calico Claude + Proxy|工具|0|0|environment|darwin|0"
  "install_yazi.sh|Yazi 檔案管理器 (+ zoxide, bat)|工具|0|0|environment|darwin linux:apt linux:pacman|0"
  "install_node.sh|Node.js 生態 (nvm + v24 + npm/yarn/pnpm)|語言|0|0|environment|all|0"
  "install_bun.sh|Bun|語言|0|0|environment|all|0"
  "install_golang.sh|Go (g 版本管理)|語言|0|0|environment|all|0"
  "install_python.sh|Python (uv)|語言|0|0|environment|all|0"
  "install_rust.sh|Rust|語言|0|0|environment|all|0"
  "install_php.sh|PHP 8.3|語言|0|0|environment|darwin linux:apt linux:pacman|0"
  "install_flutter.sh|Flutter|行動端|0|0|environment|all|1"
  "install_fvm.sh|FVM (Flutter 版本管理)|行動端|0|0|environment|all|1"
  "install_android_sdk.sh|Android SDK|行動端|0|0|environment|darwin linux|1"
  "install_gcloud.sh|Google Cloud SDK|雲端|0|0|environment|all|0"
  "install_kubectl.sh|kubectl|雲端|0|0|environment|darwin linux:apt linux:pacman|0"
  "install_argocd.sh|Argo CD CLI|雲端|0|0|environment|all|0"
  "install_sops.sh|age + sops (Secret 管理)|安全|0|0|environment|darwin linux:apt linux:pacman|0"
  "install_locale.sh|Locale 設定|基礎|0|0|environment|linux|0"
)

# -- 依平台過濾 --
ITEMS=()
for _item in "${_ALL_ITEMS[@]}"; do
  IFS='|' read -r _ _ _ _ _ _mode _platforms _optional <<< "$_item"
  if platform_supported $_platforms; then
    ITEMS+=("$_item")
  fi
done
unset _item _platforms

SETUP_MODE="config"
if [ "${1:-}" = "--environment" ]; then
  SETUP_MODE="environment"
  FILTERED_ITEMS=()
  for _item in "${ITEMS[@]}"; do
    IFS='|' read -r _ _ _ _ _ _mode _ _ <<< "$_item"
    [ "$_mode" = "environment" ] && FILTERED_ITEMS+=("$_item")
  done
  ITEMS=("${FILTERED_ITEMS[@]}")
  unset _item _mode FILTERED_ITEMS
fi

if [ "${1:-}" = "--config-only" ]; then
  exec bash "$SCRIPT_DIR/update_config.sh"
fi

TOTAL=${#ITEMS[@]}

# -- 勾選狀態陣列 --
declare -a SELECTED
for i in $(seq 0 $((TOTAL - 1))); do
  IFS='|' read -r _ _ _ config_default environment_default _ _ _ <<< "${ITEMS[$i]}"
  if [ "$SETUP_MODE" = "environment" ]; then
    SELECTED[$i]=$environment_default
  else
    SELECTED[$i]=$config_default
  fi
done

# -- 工具函式 --
get_field() {
  local idx=$1 field=$2
  IFS='|' read -r f1 f2 f3 f4 f5 f6 f7 f8 <<< "${ITEMS[$idx]}"
  case $field in
    script) echo "$f1" ;;
    name)   echo "$f2" ;;
    cat)    echo "$f3" ;;
    default) echo "$f4" ;;
    environment_default) echo "$f5" ;;
    mode)   echo "$f6" ;;
    platform) echo "$f7" ;;
    optional) echo "$f8" ;;
  esac
}

print_header() {
  printf "${C}"
  cat << 'BANNER'
  __  __ _                         ____        _    __ _ _
 |  \/  (_)_   _  __ _  __ _  ___|  _ \  ___ | |_ / _(_) | ___
 | |\/| | | | | |/ _` |/ _` |/ _ \ | | |/ _ \| __| |_| | |/ _ \
 | |  | | | |_| | (_| | (_| | (_) | |_| | (_) | |_|  _| | |  __/
 |_|  |_|_|\__, |\__,_|\__, |\___/____/ \___/ \__|_| |_|_|\___|
           |___/       |___/
BANNER
  printf "${N}\n"

  # OS Detection
  local os_name="Unknown OS"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    os_name=$(sw_vers -productName 2>/dev/null || echo "macOS")
    local os_ver=$(sw_vers -productVersion 2>/dev/null || echo "")
    os_name="$os_name $os_ver"
  elif [ -f /etc/os-release ]; then
    os_name=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2 2>/dev/null)
  fi
  printf "  ${C}OS: ${N}%s\n\n" "$os_name"

  printf "${B}  開發環境 Playbook${N}\n"
  printf "  方向鍵上下移動 | 空白鍵切換 | ${G}a${N} 全選 | ${R}n${N} 全不選 | ${Y}Enter${N} 開始安裝 | ${R}q${N} 離開\n\n"
}

print_menu() {
  local current=$1
  local term_lines
  term_lines=$(tput lines 2>/dev/null || echo 24)
  # 預留 header + 上下指示 + 計數行；其餘行數給選單項目（含分類標題）
  local avail=$(( term_lines - 15 ))
  [ "$avail" -lt 3 ] && avail=3

  # 從 start 起算，在 budget 行內最多容納到哪個 index（分類標題各佔 1 行）
  fit_end() {
    local start=$1 budget=$2 prev_cat="" lines=0 end=$((start - 1)) i cat add
    [ "$start" -gt 0 ] && prev_cat=$(get_field "$((start - 1))" cat)
    for i in $(seq "$start" $((TOTAL - 1))); do
      cat=$(get_field "$i" cat)
      add=1
      [ "$cat" != "$prev_cat" ] && add=2
      [ $((lines + add)) -gt "$budget" ] && break
      lines=$((lines + add)); prev_cat="$cat"; end=$i
    done
    echo "$end"
  }

  # scroll-into-view：游標跑出視窗才捲動，平時保留上下文，避免卡在同一段
  [ "$current" -lt "$VIEW_START" ] && VIEW_START=$current
  local end_idx
  end_idx=$(fit_end "$VIEW_START" "$avail")
  while [ "$current" -gt "$end_idx" ] && [ "$VIEW_START" -lt "$current" ]; do
    VIEW_START=$(( VIEW_START + 1 ))
    end_idx=$(fit_end "$VIEW_START" "$avail")
  done
  local start_idx=$VIEW_START

  # 上方隱藏指示
  if [ "$start_idx" -gt 0 ]; then
    printf "  ${C}↑ (還有 %d 項隱藏)${N}\033[K\n" "$start_idx"
  else
    printf "\033[K\n"
  fi

  local prev_cat=""
  [ "$start_idx" -gt 0 ] && prev_cat=$(get_field "$((start_idx - 1))" cat)

  local i
  for i in $(seq "$start_idx" "$end_idx"); do
    local name cat
    name=$(get_field "$i" name)
    cat=$(get_field "$i" cat)

    # 分類標題
    if [ "$cat" != "$prev_cat" ]; then
      printf "  ${C}── %s ──${N}\033[K\n" "$cat"
      prev_cat="$cat"
    fi

    # 勾選符號
    local check=" "
    [ "${SELECTED[$i]}" = "1" ] && check="${G}x${N}"

    # 當前游標
    local cursor="  "
    [ "$i" = "$current" ] && cursor="${Y}>${N} "

    printf "  %b [%b] %s\033[K\n" "$cursor" "$check" "$name"
  done

  # 下方隱藏指示
  if [ "$end_idx" -lt $(( TOTAL - 1 )) ]; then
    printf "  ${C}↓ (還有 %d 項隱藏)${N}\033[K\n" $(( TOTAL - 1 - end_idx ))
  else
    printf "\033[K\n"
  fi

  local count=0 s
  for s in "${SELECTED[@]}"; do [ "$s" = "1" ] && count=$((count + 1)); done
  printf "  已選擇 ${G}%d${N} / %d 項\033[K\n" "$count" "$TOTAL"

  # 清掉視窗下方殘餘行（取代每幀全螢幕 erase，消除閃爍）
  printf "\033[J"
}

select_with_fzf() {
  local action="" idx name cat default status
  local output

  for idx in $(seq 0 $((TOTAL - 1))); do
    IFS='|' read -r _ name cat _config_default _environment_default _mode _platform optional <<< "${ITEMS[$idx]}"
    if [ "${SELECTED[$idx]}" = "1" ]; then
      [ -n "$action" ] && action+="+"
      action+="toggle"
    fi
    if [ "$idx" -lt $((TOTAL - 1)) ]; then
      [ -n "$action" ] && action+="+"
      action+="down"
    fi
  done

  output=$(for idx in $(seq 0 $((TOTAL - 1))); do
    IFS='|' read -r _ name cat _config_default _environment_default _mode _platform optional <<< "${ITEMS[$idx]}"
    [ "$optional" = "1" ] && name="[optional] $name"
    printf '%s\t[%s] %s\n' "$idx" "$cat" "$name"
  done | fzf --multi \
    --height=100% --layout=reverse --border \
    --delimiter=$'\t' --with-nth=2 \
    --marker='✓ ' --pointer='▶ ' --prompt='安裝 > ' \
    --header='Space 選取  Ctrl-A 全選  Ctrl-N 清除  Enter 套用  Esc 取消' \
    --bind='space:toggle+down' \
    --bind='ctrl-a:select-all' \
    --bind='ctrl-n:deselect-all' \
    --bind="load:$action")
  status=$?

  [ "$status" -eq 0 ] || return "$status"

  for idx in $(seq 0 $((TOTAL - 1))); do
    SELECTED[$idx]=0
  done
  while IFS=$'\t' read -r idx _; do
    [ -n "$idx" ] && SELECTED[$idx]=1
  done <<< "$output"
}

cleanup() {
  tput cnorm 2>/dev/null || true
  tput rmcup 2>/dev/null || true
  stty sane 2>/dev/null || true
  [ -n "$CURRENT_RUN_LOG" ] && rm -f "$CURRENT_RUN_LOG"
  return 0
}

record_failure() {
  local name="$1"
  local script="$2"
  local status="$3"
  local output_file="${4:-}"

  {
    printf '[%s] %s (%s), exit=%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S %z')" "$name" "$script" "$status"
    if [ -n "$output_file" ] && [ -s "$output_file" ]; then
      sed 's/^/  /' "$output_file"
    fi
    printf '\n'
  } >> "$ERROR_LOG"
}

trap cleanup EXIT

# -- 非互動模式 --
if [ "${1:-}" = "--all" ] || [ "${1:-}" = "--everything" ]; then
  printf "${Y}=== 全部環境與設定模式 ===${N}\n\n"
  for i in $(seq 0 $((TOTAL - 1))); do
    optional=$(get_field "$i" optional)
    if [ "${1:-}" = "--everything" ] || [ "$optional" != "1" ]; then
      SELECTED[$i]=1
    else
      SELECTED[$i]=0
    fi
  done
else
  # -- 互動式選單 --
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf '%s\n' 'Interactive setup requires a TTY. Use --all or --config-only.' >&2
    exit 2
  fi

  current=0
  VIEW_START=0

  if command -v fzf >/dev/null 2>&1; then
    fzf_status=0
    select_with_fzf || fzf_status=$?
    if [ "$fzf_status" -eq 0 ]; then
      :
    elif [ "$fzf_status" -eq 130 ]; then
      printf "\n${Y}已取消安裝${N}\n"
      exit 0
    fi
  fi

  if [ "${fzf_status:-1}" -ne 0 ]; then
    # 隱藏游標、設定 raw mode
    tput civis 2>/dev/null || true
    tput smcup 2>/dev/null || true
    clear

    while true; do
    # 將游標移至左上角原地覆蓋；清空交給逐行 \033[K 與 print_menu 結尾的 \033[J，避免每幀全清造成閃爍
    tput cup 0 0 2>/dev/null || printf "\033[H"

    print_header
    print_menu $current

    # 讀取按鍵
    IFS= read -rsn1 key

    case "$key" in
      # 方向鍵（ESC 序列）
      $'\x1b')
        read -rsn2 -t 1 seq 2>/dev/null || true
        case "$seq" in
          '[A') # 上
            current=$(( (current - 1 + TOTAL) % TOTAL ))
            ;;
          '[B') # 下
            current=$(( (current + 1) % TOTAL ))
            ;;
        esac
        ;;
      # 空白鍵：切換勾選
      ' ')
        if [ "${SELECTED[$current]}" = "1" ]; then
          SELECTED[$current]=0
        else
          SELECTED[$current]=1
        fi
        ;;
      # vim-style navigation: j=down, k=up
      'j')
        current=$(( (current + 1) % TOTAL ))
        ;;
      'k')
        current=$(( (current - 1 + TOTAL) % TOTAL ))
        ;;
      # a: 全選
      'a')
        for i in $(seq 0 $((TOTAL - 1))); do SELECTED[$i]=1; done
        ;;
      # n: 全不選
      'n')
        for i in $(seq 0 $((TOTAL - 1))); do SELECTED[$i]=0; done
        ;;
      # Enter: 確認
      '')
        break
        ;;
      # q: 離開
      'q')
        tput cnorm 2>/dev/null || true
        tput rmcup 2>/dev/null || true
        printf "\n${Y}已取消安裝${N}\n"
        exit 0
        ;;
    esac
    done

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
  fi
fi

# -- 執行安裝 --
clear
printf "${Y}=== 開始安裝 ===${N}\n\n"

installed=0
failed=0
skipped=0

for i in $(seq 0 $((TOTAL - 1))); do
  local_script=$(get_field "$i" script)
  local_name=$(get_field "$i" name)
  script_path="$SCRIPT_DIR/$local_script"
  [ ! -f "$script_path" ] && script_path="$LINUX_DIR/$local_script"

  if [ "${SELECTED[$i]}" != "1" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [ ! -f "$script_path" ]; then
    printf "${R}  [FAIL] %s -- 腳本不存在: %s${N}\n" "$local_name" "$local_script"
    record_failure "$local_name" "$local_script" 127
    failed=$((failed + 1))
    continue
  fi

  printf "${Y}  [RUN]  %s${N}\n" "$local_name"
  CURRENT_RUN_LOG=$(mktemp /tmp/dotfile-install.XXXXXX)
  if bash "$script_path" 2>&1 | tee "$CURRENT_RUN_LOG"; then
    printf "${G}  [OK]   %s${N}\n" "$local_name"
    installed=$((installed + 1))
  else
    run_status=("${PIPESTATUS[@]}")
    script_status="${run_status[0]}"
    [ "$script_status" -eq 0 ] && script_status="${run_status[1]}"
    record_failure "$local_name" "$local_script" "$script_status" "$CURRENT_RUN_LOG"
    printf "${R}  [FAIL] %s -- 詳見 %s${N}\n" "$local_name" "$ERROR_LOG"
    failed=$((failed + 1))
  fi
  rm -f "$CURRENT_RUN_LOG"
  CURRENT_RUN_LOG=""
  echo ""
done

# -- 結果摘要 --
echo ""
printf "${Y}=== 安裝完成 ===${N}\n"
printf "  ${G}成功${N}: %d\n" "$installed"
[ "$failed" -gt 0 ] && printf "  ${R}失敗${N}: %d\n" "$failed"
printf "  略過: %d\n" "$skipped"
echo ""

if [ "$failed" -gt 0 ]; then
  printf "${R}失敗詳情已附加至 %s${N}\n" "$ERROR_LOG"
  exit 1
fi

printf "${Y}請重新啟動終端以套用所有變更${N}\n"
