# macOS-only paths and integrations.

for dir in /opt/homebrew/bin /usr/local/bin; do
  __zshrc_prepend_path_if_dir "$dir"
done

if [ -x "/opt/homebrew/opt/php@8.3/bin/php" ] || command -v php >/dev/null 2>&1; then
  __zshrc_prepend_path_if_dir "/opt/homebrew/opt/php@8.3/bin"
  __zshrc_prepend_path_if_dir "/opt/homebrew/opt/php@8.3/sbin"
fi
if [ -d "/usr/local/opt/gcc/bin" ]; then
  setopt null_glob
  for gcc_bin in "/usr/local/opt/gcc/bin"/gcc-*; do
    if [ -x "$gcc_bin" ]; then
      __zshrc_prepend_path_if_dir "/usr/local/opt/gcc/bin"
      break
    fi
  done
  unsetopt null_glob
fi
unset gcc_bin

vscode_app_bin_dir="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
if [ -x "$vscode_app_bin_dir/code" ]; then
  __zshrc_prepend_path "$vscode_app_bin_dir"
fi
unset vscode_app_bin_dir

if [ -x "$HOME/.local/bin/tokenbar-remote-sync.sh" ]; then
  ssh() {
    command ssh "$@"
    local rc=$? arg skip=0 host=""
    for arg in "$@"; do
      if (( skip )); then skip=0; continue; fi
      case "$arg" in
        -[bcDEeFIiJLlmOopQRSWw]) skip=1 ;;
        -*) ;;
        *) host="${arg#*@}"; break ;;
      esac
    done
    if [ -n "$host" ]; then
      ("$HOME/.local/bin/tokenbar-remote-sync.sh" "$host" \
        >> "$HOME/Library/Logs/tokenbar-remote-sync.log" 2>&1 &)
    fi
    return $rc
  }
fi
