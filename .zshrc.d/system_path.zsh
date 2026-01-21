__zshrc_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games /snap/bin; do
  [ -d "$dir" ] || continue
  __zshrc_prepend_path "$dir"
done
unset -f __zshrc_prepend_path
export PATH
