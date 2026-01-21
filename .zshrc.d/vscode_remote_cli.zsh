__zshrc_add_vscode_remote_cli_paths() {
  setopt local_options null_glob
  for remote_cli_dir in "$HOME"/.vscode-server/cli/servers/*/server/bin/remote-cli; do
    [ -d "$remote_cli_dir" ] || continue
    case ":$PATH:" in
      *":$remote_cli_dir:"*) ;;
      *) PATH="$remote_cli_dir:$PATH" ;;
    esac
  done
  unset remote_cli_dir
}
__zshrc_add_vscode_remote_cli_paths
unset -f __zshrc_add_vscode_remote_cli_paths
export PATH
