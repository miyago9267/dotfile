# Add utils scripts to PATH
# 直接引用 dotfile 實際路徑，不依賴 ~/script symlink
UTILS_DIR="$HOME/dotfile/script/utils"
__zshrc_prepend_path_if_dir "$UTILS_DIR"
export PATH
