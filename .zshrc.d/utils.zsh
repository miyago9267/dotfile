# Add utils scripts to PATH
UTILS_DIR="$HOME/script/utils"
if [ -d "$UTILS_DIR" ]; then
  case ":$PATH:" in
    *":$UTILS_DIR:"*) ;;
    *) PATH="$UTILS_DIR:$PATH" ;;
  esac
fi
export PATH
