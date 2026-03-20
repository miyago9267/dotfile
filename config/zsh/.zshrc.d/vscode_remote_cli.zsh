__zshrc_add_vscode_cli_paths() {
  local vscode_app_bin_dir="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  local vscode_cli="$vscode_app_bin_dir/code"

  if [ -d "$vscode_app_bin_dir" ] && [ -x "$vscode_cli" ]; then
    __zshrc_prepend_path "$vscode_app_bin_dir"
  fi

  setopt local_options null_glob
  for remote_cli_dir in "$HOME"/.vscode-server/cli/servers/*/server/bin/remote-cli; do
    [ -d "$remote_cli_dir" ] || continue
    __zshrc_prepend_path "$remote_cli_dir"
  done
  unset remote_cli_dir
  unset vscode_cli
  unset vscode_app_bin_dir
}

__zshrc_add_vscode_cli_paths
unset -f __zshrc_add_vscode_cli_paths
export PATH
