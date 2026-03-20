#!/bin/bash
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "Node.js" darwin linux
{ is_installed nvm || [ -d "$HOME/.nvm" ]; } && skip_installed "Node.js (nvm)"

# -- 安裝 nvm --
echo "安裝 nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
sleep 2
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
else
  echo "錯誤: 無法載入 nvm" >&2
  exit 1
fi

# -- 安裝 Node.js v24 --
echo "安裝 Node.js v24..."
nvm install 24
nvm alias default 24
nvm use 24

# -- 安裝全域套件管理器 --
echo "安裝 npm (latest)..."
npm install npm@latest -g

echo "安裝 yarn (latest)..."
npm install yarn@latest -g

echo "安裝 pnpm (latest)..."
npm install pnpm@latest -g

echo "Node.js 生態安裝完成 (nvm + node v24 + npm + yarn + pnpm)"
