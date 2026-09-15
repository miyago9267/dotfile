# Machine-independent local integrations.

alias agent-update='bash /Users/miyago/Project/Code/ITRD/General/agent-skills/update.sh'
alias ask='skill-run'

if [ -f "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi
__zshrc_prepend_path_if_dir "$HOME/.local/bin"
__zshrc_prepend_path_if_dir "$HOME/.opencode/bin"
export PATH

gitlab_token() {
  local host
  host=$(git remote get-url origin 2>/dev/null | sed 's|https\?://\([^/]*\).*|\1|')
  git config --get gitlab."https://${host}".token
}
