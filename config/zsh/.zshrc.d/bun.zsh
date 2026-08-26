if [ -x "$HOME/.bun/bin/bun" ] || command -v bun >/dev/null 2>&1; then
  export BUN_INSTALL="$HOME/.bun"
  BUN_BIN_DIR="$BUN_INSTALL/bin"
  __zshrc_prepend_path_if_dir "$BUN_BIN_DIR"
  [ -r "$BUN_INSTALL/_bun" ] && . "$BUN_INSTALL/_bun"
  unset BUN_BIN_DIR
fi
export PATH
