#!/bin/bash
# Safe, plz remove belove line if u need to start install
exit

# color
Y='\033[1;33m'
N='\033[0m'

printf "${Y}Start modular setup...${N}\n"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

SCRIPT_DIR="$DIR/script/installations"

bash $SCRIPT_DIR/dependencis.sh
bash $SCRIPT_DIR/install_poetry_pyenv.sh
bash $SCRIPT_DIR/install_node.sh
bash $SCRIPT_DIR/setup_zsh.sh
bash $SCRIPT_DIR/setup_fonts.sh
bash $SCRIPT_DIR/setup_dotfiles.sh
bash $SCRIPT_DIR/setup_vim.sh

printf "${Y}Finished!\nPlease restart your device to apply\n${N}"
