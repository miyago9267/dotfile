for dir in "$HOME/fvm/bin" "$HOME/.pub-cache/bin"; do
  [ -d "$dir" ] || continue
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
done
export PATH
