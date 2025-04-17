#!/bin/sh
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh

if ! command -v zsh >/dev/null; then
  chsh -s "$(command -v zsh)"
fi

zsh -c "source ~/.zshrc"
