OPENCLAW_COMPLETION_FILE="$HOME/.openclaw/completions/openclaw.zsh"
if [ -r "$OPENCLAW_COMPLETION_FILE" ]; then
  . "$OPENCLAW_COMPLETION_FILE"
elif command -v openclaw >/dev/null 2>&1; then
  source <(openclaw completion --shell zsh)
fi
unset OPENCLAW_COMPLETION_FILE
