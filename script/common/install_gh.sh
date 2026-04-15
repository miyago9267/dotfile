#!/bin/bash
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "Git CLI Tools (gh/glab)" darwin linux:apt linux:pacman

Y="\033[1;33m"
G="\033[1;32m"
R="\033[1;31m"
N="\033[0m"

# --- GitHub CLI (gh) ---
install_gh() {
  if is_installed gh; then
    if [ "$_PLATFORM_PKG" = "brew" ]; then
      outdated_info=$(brew outdated gh)
      if [ -z "$outdated_info" ]; then
        echo -e "${G}[SKIP] GitHub CLI (gh): 已安裝且為最新版本${N}"
      else
        echo -e "${Y}[UPDATE] GitHub CLI (gh): 正在更新...${N}"
        brew upgrade gh
      fi
    else
      echo -e "${G}[SKIP] GitHub CLI (gh): 已安裝${N}"
    fi
  else
    echo -e "${Y}[INSTALL] GitHub CLI (gh): 正在安裝...${N}"
    if [ "$_PLATFORM_PKG" = "brew" ]; then
      brew install gh
    elif [ "$_PLATFORM_DISTRO" = "arch" ]; then
      sudo pacman -S --noconfirm github-cli
    elif [ "$_PLATFORM_DISTRO" = "debian" ]; then
      (type -p wget >/dev/null || sudo apt install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install -y gh
      rm -f "$out"
    fi
  fi

  # Optional Login
  if is_installed gh; then
    if ! gh auth status &>/dev/null; then
      printf "\n${Y}GitHub CLI (gh) 尚未登入。是否現在登入？ (y/N) ${N}"
      read -r -n 1 opt
      echo ""
      if [[ "$opt" =~ ^[Yy]$ ]]; then
        gh auth login
      fi
    fi
  fi
}

# --- GitLab CLI (glab) ---
install_glab() {
  if is_installed glab; then
    if [ "$_PLATFORM_PKG" = "brew" ]; then
      outdated_info=$(brew outdated glab)
      if [ -z "$outdated_info" ]; then
        echo -e "${G}[SKIP] GitLab CLI (glab): 已安裝且為最新版本${N}"
      else
        echo -e "${Y}[UPDATE] GitLab CLI (glab): 正在更新...${N}"
        brew upgrade glab
      fi
    else
      echo -e "${G}[SKIP] GitLab CLI (glab): 已安裝${N}"
    fi
  else
    echo -e "${Y}[INSTALL] GitLab CLI (glab): 正在安裝...${N}"
    if [ "$_PLATFORM_PKG" = "brew" ]; then
      brew install glab
    elif [ "$_PLATFORM_DISTRO" = "arch" ]; then
      sudo pacman -S --noconfirm glab
    elif [ "$_PLATFORM_DISTRO" = "debian" ]; then
      sudo apt install -y glab
    fi
  fi

  # Optional Login
  if is_installed glab; then
    if ! glab auth status &>/dev/null; then
      printf "\n${Y}GitLab CLI (glab) 尚未登入。是否現在登入？ (y/N) ${N}"
      read -r -n 1 opt
      echo ""
      if [[ "$opt" =~ ^[Yy]$ ]]; then
        glab auth login
      fi
    fi
  fi
}

install_gh
echo ""
install_glab

