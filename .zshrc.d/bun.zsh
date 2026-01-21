export BUN_INSTALL="$HOME/.bun"
if [ -d "$BUN_INSTALL/bin" ]; then
  case ":$PATH:" in
    *":$BUN_INSTALL/bin:"*) ;;
    *) PATH="$BUN_INSTALL/bin:$PATH" ;;
  esac
fi
[ -s "$BUN_INSTALL/_bun" ] && . "$BUN_INSTALL/_bun"
export PATH
