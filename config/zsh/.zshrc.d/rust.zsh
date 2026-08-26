if [ -x "$HOME/.cargo/bin/cargo" ] || command -v cargo >/dev/null 2>&1; then
  [ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
fi
