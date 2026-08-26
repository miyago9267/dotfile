if [ -x "$HOME/development/flutter/bin/flutter" ] || command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN_DIR="$HOME/development/flutter/bin"
  __zshrc_prepend_path_if_dir "$FLUTTER_BIN_DIR"
  unset FLUTTER_BIN_DIR
fi
export PATH
