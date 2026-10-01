PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
# WSL appends the Windows PATH; ignore pyenv-win under /mnt/.
__zshrc_native_pyenv() {
  local p
  p="$(command -v pyenv 2>/dev/null)" || return 1
  [[ "$p" != /mnt/* ]]
}
if [ -x "$PYENV_ROOT/bin/pyenv" ] || __zshrc_native_pyenv; then
  export PYENV_ROOT="$HOME/.pyenv"
  __zshrc_prepend_path_if_dir "$PYENV_ROOT/bin"
  __zshrc_prepend_path_if_dir "$PYENV_ROOT/shims"
  if __zshrc_native_pyenv; then
    eval "$(pyenv init - --no-rehash zsh)"
  elif [ -x "$PYENV_ROOT/bin/pyenv" ]; then
    eval "$($PYENV_ROOT/bin/pyenv init - --no-rehash zsh)"
  fi
else
  unset PYENV_ROOT
fi
export PATH
