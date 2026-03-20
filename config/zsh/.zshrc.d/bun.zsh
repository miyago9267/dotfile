export BUN_INSTALL="$HOME/.bun"
BUN_BIN_DIR="$BUN_INSTALL/bin"
__zshrc_prepend_path_if_dir "$BUN_BIN_DIR"
[ -s "$BUN_INSTALL/_bun" ] && . "$BUN_INSTALL/_bun"
unset BUN_BIN_DIR
export PATH
