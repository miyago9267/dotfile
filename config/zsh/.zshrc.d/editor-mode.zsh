# editor-mode.zsh -- 讓 shell input 像編輯器一樣操作
# 多行編輯、游標自由移動、Ctrl+E 開 $EDITOR

# ── 多行輸入 ──────────────────────────────────
# Alt+Enter / Option+Enter 插入換行（不執行）
bindkey '^[^M' self-insert-unmeta  # 部分 terminal 送這個
bindkey '\e\r' self-insert-unmeta

# 手動 newline widget（相容性更好）
_editor_mode_newline() {
  LBUFFER+=$'\n'
}
zle -N _editor_mode_newline
# Warp 的 Enter 送 ^J 而非 ^M，綁 ^J 會讓 Enter 無法執行指令
[[ "$TERM_PROGRAM" != "WarpTerminal" ]] && bindkey '^J' _editor_mode_newline  # Ctrl+J = 換行

# ── 多行時游標上下移動（不觸發 history）──────
_editor_mode_up() {
  if [[ "$BUFFER" == *$'\n'* ]] && [[ "$LBUFFER" == *$'\n'* ]]; then
    zle up-line
  else
    zle up-line-or-history
  fi
}

_editor_mode_down() {
  if [[ "$BUFFER" == *$'\n'* ]] && [[ "$RBUFFER" == *$'\n'* ]]; then
    zle down-line
  else
    zle down-line-or-history
  fi
}

zle -N _editor_mode_up
zle -N _editor_mode_down
bindkey '^[[A' _editor_mode_up    # Up arrow
bindkey '^[[B' _editor_mode_down  # Down arrow
bindkey '^[OA' _editor_mode_up    # Up (application mode)
bindkey '^[OB' _editor_mode_down  # Down (application mode)

# ── 用 $EDITOR 編輯當前指令 ──────────────────
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line   # Ctrl+X Ctrl+E
bindkey '^E' edit-command-line     # Ctrl+E 直接開

# ── 行首/行尾（Mac 友好）─────────────────────
bindkey '^A' beginning-of-line     # Ctrl+A = 行首
bindkey '^[[H' beginning-of-line   # Home (有外接鍵盤時)
bindkey '^[[F' end-of-line         # End (有外接鍵盤時)
# Cmd+Left/Right 由 terminal emulator 送出，通常是這些：
bindkey '^[[1;2D' beginning-of-line  # Shift+Left (iTerm2 可設)
bindkey '^[[1;2C' end-of-line        # Shift+Right (iTerm2 可設)

# ── Option+左右 跳 word ──────────────────────
bindkey '^[b' backward-word        # Option+Left / Alt+B
bindkey '^[f' forward-word         # Option+Right / Alt+F
bindkey '^[[1;3D' backward-word    # Option+Left (xterm)
bindkey '^[[1;3C' forward-word     # Option+Right (xterm)

# ── Option+Delete 刪整個 word ────────────────
bindkey '^[^?' backward-kill-word  # Option+Backspace
bindkey '^[[3;3~' kill-word        # Option+Fn+Backspace (forward delete word)
