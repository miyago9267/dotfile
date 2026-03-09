__zshrc_prepend_path() {
  [ -n "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

__zshrc_prepend_path_if_dir() {
  [ -d "$1" ] || return 0
  __zshrc_prepend_path "$1"
}
