for dir in "$HOME/.zplug/repos/zplug/zplug/bin" "$HOME/.zplug/bin"; do
  [ -d "$dir" ] || continue
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
done
export PATH
