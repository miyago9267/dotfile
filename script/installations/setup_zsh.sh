#!/bin/sh
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh

if ! command -v zsh >/dev/null; then
  chsh -s "$(command -v zsh)"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure modular env directory exists
mkdir -p "$HOME/.zshrc.d"

if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" zplug
fi

echo "zsh setup complete. Restart terminal or run 'exec zsh' to apply changes"
