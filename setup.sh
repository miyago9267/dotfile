#!/bin/bash
# Safe, plz remove belove line if u need to start install
# exit

# color
Y='\033[1;33m'
N='\033[0m'

printf "${Y}Start modular setup...${N}\n"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

SCRIPT_DIR="$DIR/script/installations"

for script in "$SCRIPT_DIR"/*.sh; do
  echo -e "${Y}Running $script...${N}"
  bash -x "$script"
done

printf "${Y}Finished!\nPlease restart your device to apply\n${N}"
