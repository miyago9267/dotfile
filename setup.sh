#!/bin/bash
# Miyago Dotfile 互動式安裝腳本
# 使用方式：bash setup.sh [--all]
#   --all  跳過選單，直接安裝全部

set -e

# -- 色彩 --
Y='\033[1;33m'
G='\033[1;32m'
C='\033[1;36m'
R='\033[1;31m'
B='\033[1m'
N='\033[0m'

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$DIR/script/installations"

# -- 安裝項目定義 --
# 格式：腳本檔名|顯示名稱|分類|預設勾選(1/0)
ITEMS=(
  "dependencis.sh|基礎依賴套件 (Homebrew 等)|基礎|1"
  "setup_dotfiles.sh|Dotfiles 連結 (symlink)|基礎|1"
  "setup_zsh.sh|Zsh 設定|Shell|1"
  "setup_vim.sh|Vim 設定|編輯器|1"
  "setup_neovim.sh|Neovim 設定|編輯器|1"
  "setup_tmux.sh|Tmux 設定|終端|1"
  "setup_fonts.sh|字型安裝|基礎|1"
  "setup_claude.sh|Claude Code 設定 (symlink)|工具|1"
  "install_node.sh|Node.js (nvm)|語言|0"
  "install_pnpm.sh|pnpm|語言|0"
  "install_bun.sh|Bun|語言|0"
  "install_golang.sh|Go (g 版本管理)|語言|0"
  "install_python.sh|Python (pyenv + uv)|語言|0"
  "install_rust.sh|Rust|語言|0"
  "install_php.sh|PHP 8.3|語言|0"
  "install_flutter.sh|Flutter|行動端|0"
  "install_fvm.sh|FVM (Flutter 版本管理)|行動端|0"
  "install_android_sdk.sh|Android SDK|行動端|0"
  "install_gcloud.sh|Google Cloud SDK|雲端|0"
  "install_kubectl.sh|kubectl|雲端|0"
  "install_locale.sh|Locale 設定|基礎|0"
)

TOTAL=${#ITEMS[@]}

# -- 勾選狀態陣列 --
declare -a SELECTED
for i in $(seq 0 $((TOTAL - 1))); do
  IFS='|' read -r _ _ _ default <<< "${ITEMS[$i]}"
  SELECTED[$i]=$default
done

# -- 工具函式 --
get_field() {
  local idx=$1 field=$2
  IFS='|' read -r f1 f2 f3 f4 <<< "${ITEMS[$idx]}"
  case $field in
    script) echo "$f1" ;;
    name)   echo "$f2" ;;
    cat)    echo "$f3" ;;
    default) echo "$f4" ;;
  esac
}

print_header() {
  clear
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
  printf "${B}  互動式安裝程式${N}\n"
  printf "  方向鍵上下移動 | 空白鍵切換 | ${G}a${N} 全選 | ${R}n${N} 全不選 | ${Y}Enter${N} 開始安裝 | ${R}q${N} 離開\n\n"
}

print_menu() {
  local current=$1
  local prev_cat=""

  for i in $(seq 0 $((TOTAL - 1))); do
    local name
    name=$(get_field "$i" name)
    local cat
    cat=$(get_field "$i" cat)

    # 分類標題
    if [ "$cat" != "$prev_cat" ]; then
      [ -n "$prev_cat" ] && echo ""
      printf "  ${C}── %s ──${N}\n" "$cat"
      prev_cat="$cat"
    fi

    # 勾選符號
    local check=" "
    [ "${SELECTED[$i]}" = "1" ] && check="${G}x${N}"

    # 當前游標
    local cursor="  "
    [ "$i" = "$current" ] && cursor="${Y}>${N} "

    printf "  %b [%b] %s\n" "$cursor" "$check" "$name"
  done

  echo ""
  local count=0
  for s in "${SELECTED[@]}"; do [ "$s" = "1" ] && count=$((count + 1)); done
  printf "  已選擇 ${G}%d${N} / %d 項\n" "$count" "$TOTAL"
}

# -- 全部安裝模式 --
if [ "$1" = "--all" ]; then
  printf "${Y}=== 全部安裝模式 ===${N}\n\n"
  for i in $(seq 0 $((TOTAL - 1))); do
    SELECTED[$i]=1
  done
else
  # -- 互動式選單 --
  current=0

  # 隱藏游標、設定 raw mode
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null; stty sane 2>/dev/null' EXIT

  while true; do
    print_header
    print_menu $current

    # 讀取按鍵
    IFS= read -rsn1 key

    case "$key" in
      # 方向鍵（ESC 序列）
      $'\x1b')
        read -rsn2 -t 0.1 seq
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
      # j/k 也可以（Miyago 習慣 j=上 k=下）
      'j')
        current=$(( (current - 1 + TOTAL) % TOTAL ))
        ;;
      'k')
        current=$(( (current + 1) % TOTAL ))
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
        printf "\n${Y}已取消安裝${N}\n"
        exit 0
        ;;
    esac
  done

  # 恢復游標
  tput cnorm 2>/dev/null || true
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

  if [ "${SELECTED[$i]}" != "1" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  if [ ! -f "$script_path" ]; then
    printf "${R}  [SKIP] %s -- 腳本不存在: %s${N}\n" "$local_name" "$local_script"
    skipped=$((skipped + 1))
    continue
  fi

  printf "${Y}  [RUN]  %s${N}\n" "$local_name"
  if bash "$script_path"; then
    printf "${G}  [OK]   %s${N}\n" "$local_name"
    installed=$((installed + 1))
  else
    printf "${R}  [FAIL] %s${N}\n" "$local_name"
    failed=$((failed + 1))
  fi
  echo ""
done

# -- 結果摘要 --
echo ""
printf "${Y}=== 安裝完成 ===${N}\n"
printf "  ${G}成功${N}: %d\n" "$installed"
[ "$failed" -gt 0 ] && printf "  ${R}失敗${N}: %d\n" "$failed"
printf "  略過: %d\n" "$skipped"
echo ""
printf "${Y}請重新啟動終端以套用所有變更${N}\n"
