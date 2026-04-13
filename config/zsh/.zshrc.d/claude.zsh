# Claude Code CLI (installed to ~/.local/bin via npm)
__zshrc_prepend_path_if_dir "$HOME/.local/bin"

# Auto-patch buddy on new Claude Code versions (lightweight check)
if [[ -d "$HOME/.local/share/claude/versions" ]]; then
  _buddy_current=$(ls -t "$HOME/.local/share/claude/versions" 2>/dev/null | grep -v '\.bak' | head -1)
  _buddy_stamped=$(cat "$HOME/.claude/.buddy-patched-version" 2>/dev/null)
  if [[ -n "$_buddy_current" && "$_buddy_current" != "$_buddy_stamped" ]]; then
    echo "[buddy-watch] New Claude Code version detected: $_buddy_current"
    bash ~/dotfile/config/ai/claude/scripts/buddy/buddy-watch.sh &>/dev/null &
    disown
  fi
  unset _buddy_current _buddy_stamped
fi
