for dir in "$HOME/fvm/bin" "$HOME/.pub-cache/bin"; do
  __zshrc_prepend_path_if_dir "$dir"
done
export PATH
