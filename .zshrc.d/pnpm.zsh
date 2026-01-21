export PNPM_HOME="$HOME/.local/share/pnpm"
if [ -d "$PNPM_HOME" ]; then
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) PATH="$PNPM_HOME:$PATH" ;;
  esac
fi
export PATH
