if [ -x "$HOME/fvm/bin/fvm" ] || command -v fvm >/dev/null 2>&1; then
  for dir in "$HOME/fvm/bin" "$HOME/.pub-cache/bin"; do
    __zshrc_prepend_path_if_dir "$dir"
  done
fi
unset dir
export PATH
