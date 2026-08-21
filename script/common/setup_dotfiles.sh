#!/bin/sh
Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"
echo "${Y}Building link to dotfiles${N}"
dotfile_dir="${MIYAGO_DOTFILE_ROOT:-$HOME/dotfile}"
workspace_dir="${MIYAGO_AGENT_WORKSPACE_ROOT:-$dotfile_dir/../Project/AI/agent-workspace}"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$config_root" "$config_root/ghostty" "$config_root/miyago-agent/personal-model"

link() {
  src="$1"; dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ${G}[OK]${N} $dst"
  else
    ln -sf "$src" "$dst"
    echo "  ${Y}[LINK]${N} $dst -> $src"
  fi
}

link "$dotfile_dir/config/bash/.bashrc"      "$HOME/.bashrc"
link "$dotfile_dir/config/zsh/.zshrc"        "$HOME/.zshrc"
link "$dotfile_dir/config/zsh/.zshrc.d"      "$HOME/.zshrc.d"
link "$dotfile_dir/config/zsh/.p10k.zsh"     "$HOME/.p10k.zsh"
link "$dotfile_dir/config/zsh/alias.sh"      "$HOME/alias.sh"
link "$dotfile_dir/config/vim/.vimrc"        "$HOME/.vimrc"
link "$dotfile_dir/config/nvim"              "$config_root/nvim"
link "$dotfile_dir/config/ghostty/config"    "$config_root/ghostty/config"
link "$dotfile_dir/config/fastfetch"         "$config_root/fastfetch"
link "$dotfile_dir/config/opencode"          "$config_root/opencode"
link "$dotfile_dir/config/opencode-harness"  "$config_root/opencode-harness"
link "$dotfile_dir/config/opencode-studio"   "$config_root/opencode-studio"

# OpenCode reads these stable, runtime-neutral paths. The links preserve one
# canonical source while keeping config files portable across machines.
link "$dotfile_dir/config/ai/AGENTS.md" "$config_root/miyago-agent/AGENTS.md"
link "$workspace_dir/personal-model/PROFILE.md" "$config_root/miyago-agent/personal-model/PROFILE.md"
