if [ -d "$HOME/development/flutter/bin" ]; then
  case ":$PATH:" in
    *":$HOME/development/flutter/bin:"*) ;;
    *) PATH="$HOME/development/flutter/bin:$PATH" ;;
  esac
fi
export PATH
