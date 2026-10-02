# 全域找資料夾並 cd：`fcd [關鍵字]` 或 Ctrl-G
# 來源：zoxide 常去的目錄（立刻出現、排最前面）+ 家目錄底下所有資料夾（fd 邊掃邊顯示）
if command -v fzf >/dev/null 2>&1; then
  __jump_fd="$(command -v fd || command -v fdfind)"

  # 不會想 cd 進去、又佔掉大量掃描時間的目錄
  __jump_excludes=(
    Library OrbStack Volumes google-cloud-sdk Applications .Trash
    node_modules .git .cache .venv venv __pycache__ target dist build vendor pkg
  )

  __jump_source() {
    command -v zoxide >/dev/null 2>&1 && zoxide query --list 2>/dev/null
    if [ -n "$__jump_fd" ]; then
      local args=() name
      for name in $__jump_excludes; do args+=(--exclude "$name"); done
      "$__jump_fd" --type d "${args[@]}" . "$HOME" 2>/dev/null
    else
      find "$HOME" -type d -not -path '*/.*' -not -path "$HOME/Library/*" 2>/dev/null
    fi
  }

  # 選一個資料夾並印出絕對路徑；沒選就回傳非 0
  __jump_pick() {
    local dir
    dir="$(__jump_source \
      | sed -e 's|/$||' -e "s|^$HOME|~|" \
      | awk '!seen[$0]++' \
      | fzf --scheme=path --tiebreak=index --query "$*" --prompt 'cd> ' \
          --preview 'p={}; p="${p/#\~/$HOME}"; tree -C -L 2 "$p" 2>/dev/null | head -200 || ls -la "$p"' \
          --bind 'ctrl-/:toggle-preview')" || return 1
    [ -n "$dir" ] || return 1
    print -r -- "${dir/#\~/$HOME}"
  }

  fcd() {
    local dir
    dir="$(__jump_pick "$@")" || return
    builtin cd -- "$dir"
  }

  __jump_widget() {
    local dir
    dir="$(__jump_pick "$LBUFFER")"
    if [ -n "$dir" ]; then
      BUFFER="builtin cd -- ${(q)dir}"
      zle accept-line
    else
      zle reset-prompt
    fi
  }
  zle -N __jump_widget
  bindkey '^G' __jump_widget
fi
