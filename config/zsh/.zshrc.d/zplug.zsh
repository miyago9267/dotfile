for dir in "$HOME/.zplug/repos/zplug/zplug/bin" "$HOME/.zplug/bin"; do
  __zshrc_prepend_path_if_dir "$dir"
done
export PATH
