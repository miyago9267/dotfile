# editor-mode.zsh -- tmux Shift+Enter 換行支援
# tmux extended-keys 送出 CSI u 序列，這裡接收並插入換行

_editor_mode_newline() {
  LBUFFER+=$'\n'
}
zle -N _editor_mode_newline
bindkey '\e[13;2u' _editor_mode_newline  # Shift+Enter (tmux S-Enter)
