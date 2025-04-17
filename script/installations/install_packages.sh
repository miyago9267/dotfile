#!/bin/sh
Y="\033[1;33m"
N="\033[0m"

if command -v apt >/dev/null; then
  cmd="sudo apt install -y"
  packages="zsh git curl neovim gawk tmux libtool autoconf automake cmake libncurses5-dev g++ clang"
elif command -v pacman >/dev/null; then
  cmd="sudo pacman -S --noconfirm"
  packages="zsh git curl neovim python-pynvim tmux cmake g++ clang"
elif command -v brew >/dev/null; then
  cmd="brew install"
  packages="zsh curl git tmux"
else
  echo "No supported package manager found"
  exit 1
fi

for pkg in $packages; do
  printf "${Y}Installing ${pkg}${N}
"
  $cmd $pkg
done
