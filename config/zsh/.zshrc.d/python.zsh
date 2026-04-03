export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  __zshrc_prepend_path_if_dir "$PYENV_ROOT/bin"
  __zshrc_prepend_path_if_dir "$PYENV_ROOT/shims"
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - --no-rehash zsh)"
  elif [ -x "$PYENV_ROOT/bin/pyenv" ]; then
    eval "$($PYENV_ROOT/bin/pyenv init - --no-rehash zsh)"
  fi
fi
export PATH
