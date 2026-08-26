PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
if [ -x "$PYENV_ROOT/bin/pyenv" ] || command -v pyenv >/dev/null 2>&1; then
  export PYENV_ROOT="$HOME/.pyenv"
  __zshrc_prepend_path_if_dir "$PYENV_ROOT/bin"
  __zshrc_prepend_path_if_dir "$PYENV_ROOT/shims"
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - --no-rehash zsh)"
  elif [ -x "$PYENV_ROOT/bin/pyenv" ]; then
    eval "$($PYENV_ROOT/bin/pyenv init - --no-rehash zsh)"
  fi
else
  unset PYENV_ROOT
fi
export PATH
