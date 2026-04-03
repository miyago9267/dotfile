#!/bin/sh
# dotfile-track: 把散落的 config 收進 dotfile repo 並建 symlink
#
# Usage:
#   dotfile-track <file>                     自動推導 repo 路徑
#   dotfile-track <file> <repo-subpath>      指定 repo 內的子路徑
#
# Examples:
#   dotfile-track ~/.config/ghostty/config
#     -> ~/dotfile/config/ghostty/config (自動推導)
#
#   dotfile-track ~/.config/karabiner/karabiner.json config/karabiner/karabiner.json
#     -> ~/dotfile/config/karabiner/karabiner.json (手動指定)
#
#   dotfile-track ~/.ssh/config
#     -> ~/dotfile/config/ssh/config

set -e

Y="\033[1;33m"
G="\033[1;32m"
R="\033[1;31m"
N="\033[0m"

DOTFILE_DIR="$HOME/dotfile"
SETUP_SCRIPT="$DOTFILE_DIR/script/common/setup_dotfiles.sh"

usage() {
  echo "Usage: dotfile-track <file> [repo-subpath]"
  echo ""
  echo "Examples:"
  echo "  dotfile-track ~/.config/ghostty/config"
  echo "  dotfile-track ~/.ssh/config config/ssh/config"
  exit 1
}

[ -z "$1" ] && usage

# -- Resolve source path --
src="$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1")"

if [ ! -e "$src" ]; then
  echo "${R}[ERR]${N} File not found: $src"
  exit 1
fi

if [ -L "$src" ]; then
  target="$(readlink "$src")"
  case "$target" in
    "$DOTFILE_DIR"*)
      echo "${G}[OK]${N} Already tracked: $src -> $target"
      exit 0
      ;;
  esac
fi

# -- Determine repo destination --
if [ -n "$2" ]; then
  repo_rel="$2"
else
  # Auto-derive: strip $HOME prefix, map .config/X -> config/X, .X -> config/X
  rel="${src#$HOME/}"
  case "$rel" in
    .config/*)
      repo_rel="config/${rel#.config/}"
      ;;
    .*)
      # dot-prefixed file: .vimrc -> config/vim/.vimrc
      # Just put it under config/ with parent dir name
      name="$(basename "$rel")"
      repo_rel="config/${name#.}/$name"
      ;;
    *)
      repo_rel="config/$rel"
      ;;
  esac
fi

repo_dst="$DOTFILE_DIR/$repo_rel"

# -- Confirm --
echo "${Y}[PLAN]${N} $src"
echo "    -> $repo_dst (copy to repo)"
echo "    -> $src (replace with symlink)"

printf "  Proceed? [Y/n]: "
read -r ans
case "$ans" in
  [nN]*) echo "Cancelled."; exit 0 ;;
esac

# -- Execute --
# 1. Create directory in repo
mkdir -p "$(dirname "$repo_dst")"

# 2. Copy file to repo (preserve permissions)
cp -p "$src" "$repo_dst"
echo "${G}[COPY]${N} $repo_dst"

# 3. Replace original with symlink
ln -sf "$repo_dst" "$src"
echo "${G}[LINK]${N} $src -> $repo_dst"

# 4. Register in setup_dotfiles.sh if not already there
# Build the link() line using $dir-relative path and ~-relative target
link_src="\$dir/$repo_rel"
link_dst="$src"
# Convert absolute home path to ~/... for display, but use actual path for matching
link_dst_short="${link_dst#$HOME/}"

# Check if already registered (match on the destination)
if grep -q "$link_dst_short" "$SETUP_SCRIPT" 2>/dev/null; then
  echo "${G}[OK]${N} Already in setup_dotfiles.sh"
else
  # Find the last link() line and append after it
  # Use ~ expansion patterns that setup_dotfiles.sh uses
  case "$link_dst_short" in
    .config/*) setup_dst="~/.config/${link_dst_short#.config/}" ;;
    *)         setup_dst="~/$link_dst_short" ;;
  esac

  # Append before the trailing blank line
  sed_pattern="link \"\$dir/$repo_rel\""
  if ! grep -qF "$sed_pattern" "$SETUP_SCRIPT"; then
    # Find line number of last "link " call
    last_link_line=$(grep -n '^link ' "$SETUP_SCRIPT" | tail -1 | cut -d: -f1)
    if [ -n "$last_link_line" ]; then
      # Insert after last link line
      sed -i.bak "${last_link_line}a\\
link \"\$dir/$repo_rel\"$(printf '%*s' $((24 - ${#repo_rel})) '')$setup_dst
" "$SETUP_SCRIPT"
      rm -f "${SETUP_SCRIPT}.bak"
      echo "${G}[REG]${N} Added to setup_dotfiles.sh"
    else
      echo "${Y}[WARN]${N} Could not find insertion point in setup_dotfiles.sh"
      echo "  Add manually: link \"\$dir/$repo_rel\" $setup_dst"
    fi
  fi
fi

echo ""
echo "${G}Done.${N} Don't forget to commit."
