#!/bin/sh
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "TUI Tools" darwin linux:apt linux:pacman

# Charm APT repo (shared by glow, vhs, slides, etc.)
_setup_charm_apt() {
  if [ "$_PLATFORM_PKG" = "apt" ] && [ ! -f /etc/apt/keyrings/charm.gpg ]; then
    echo "Setting up Charm APT repository..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt-get update
  fi
}

# Generic installer: _install <cmd> <display_name> <brew_pkg> <apt_pkg> <pacman_pkg>
_install() {
  _cmd="$1"; _name="$2"; _brew="$3"; _apt="$4"; _pacman="$5"
  if is_installed "$_cmd"; then
    echo "[SKIP] $_name: already installed"
    return 0
  fi
  echo "Installing $_name..."
  case "$_PLATFORM_PKG" in
    brew)   brew install "$_brew" ;;
    apt)    sudo apt-get install -y "$_apt" ;;
    pacman) sudo pacman -S --noconfirm "$_pacman" ;;
  esac
}

# --- Go / Binary TUI tools ---
# Format: command, display name, brew pkg, apt pkg, pacman pkg

_setup_charm_apt

_install lazygit    "lazygit (Git TUI)"          lazygit    lazygit    lazygit
_install lazydocker "lazydocker (Docker TUI)"    lazydocker lazydocker lazydocker
_install k9s       "k9s (Kubernetes TUI)"        k9s        k9s        k9s
_install btop      "btop (system monitor)"       btop       btop       btop
_install vhs       "VHS (terminal recorder)"     vhs        vhs        vhs
_install spf       "superfile (file manager)"    superfile  superfile  superfile
_install glow      "Glow (markdown renderer)"    glow       glow       glow
_install slides    "slides (terminal slides)"    slides     slides     slides
_install presenterm "presenterm (presentations)" presenterm presenterm presenterm
_install lazysql   "lazysql (database TUI)"      lazysql    lazysql    lazysql

# --- Python TUI tools (via pipx) ---
_install_pipx() {
  _cmd="$1"; _name="$2"; _pkg="$3"
  if is_installed "$_cmd"; then
    echo "[SKIP] $_name: already installed"
    return 0
  fi
  if ! is_installed pipx; then
    echo "Installing pipx..."
    case "$_PLATFORM_PKG" in
      brew)   brew install pipx ;;
      apt)    sudo apt-get install -y pipx ;;
      pacman) sudo pacman -S --noconfirm python-pipx ;;
    esac
  fi
  echo "Installing $_name via pipx..."
  pipx install "$_pkg"
}

_install_pipx posting   "posting (API client TUI)"   posting
_install_pipx harlequin "harlequin (SQL IDE TUI)"    harlequin

echo ""
echo "TUI tools installation complete."
