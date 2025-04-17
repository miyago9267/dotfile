#!/bin/sh
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh

if ! command -v zsh >/dev/null; then
  chsh -s "$(command -v zsh)"
fi

echo "✅ zsh 安裝完成，請重新啟動終端或執行 'exec zsh' 套用設定"
