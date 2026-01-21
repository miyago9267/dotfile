export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  case ":$PATH:" in
    *":$PYENV_ROOT/bin:"*) ;;
    *) PATH="$PYENV_ROOT/bin:$PATH" ;;
  esac
  case ":$PATH:" in
    *":$PYENV_ROOT/shims:"*) ;;
    *) PATH="$PYENV_ROOT/shims:$PATH" ;;
  esac
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
  elif [ -x "$PYENV_ROOT/bin/pyenv" ]; then
    eval "$($PYENV_ROOT/bin/pyenv init -)"
  fi
fi
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
