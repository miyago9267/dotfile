#!/bin/sh
Y="\033[1;33m"
N="\033[0m"

if command -v apt >/dev/null; then
  cmd="sudo apt install -y"
  packages="zsh git curl neovim gawk tmux libtool autoconf automake cmake libncurses5-dev g++ clang"
elif command -v pacman >/dev/null; then
  cmd="sudo pacman -S --noconfirm"
  packages="zsh git curl neovim python-pynvim tmux cmake g++ clang"
elif [ "$(uname)" = "Darwin" ]; then
  if ! command -v brew >/dev/null; then
    echo "${Y}Installing Homebrew...${N}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  cmd="brew install"
  packages="zsh curl git tmux go neovim"
else
  echo "No supported package manager found"
  exit 1
fi

for pkg in $packages; do
  printf "${Y}Installing ${pkg}${N}
"
  $cmd $pkg
done
