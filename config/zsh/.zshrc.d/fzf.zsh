# fzf：用 fd 找檔案/目錄，加上 preview；沒有 fd 時維持 fzf 預設行為
__fzf_fd="$(command -v fd || command -v fdfind)"
__fzf_bat="$(command -v bat || command -v batcat)"

if [ -n "$__fzf_fd" ]; then
  __fzf_fd_opts="--hidden --follow --exclude .git --exclude node_modules --exclude .cache --exclude Library"
  export FZF_DEFAULT_COMMAND="$__fzf_fd --type f $__fzf_fd_opts"
  export FZF_CTRL_T_COMMAND="$__fzf_fd --type f --type d $__fzf_fd_opts"
  export FZF_ALT_C_COMMAND="$__fzf_fd --type d $__fzf_fd_opts"
  # `vim **<Tab>`、`cd **<Tab>` 也改用 fd
  eval "_fzf_compgen_path() { $__fzf_fd $__fzf_fd_opts . \"\$1\" }"
  eval "_fzf_compgen_dir() { $__fzf_fd --type d $__fzf_fd_opts . \"\$1\" }"
fi

export FZF_DEFAULT_OPTS="--height 50% --layout reverse --border --info inline-right --cycle"

if [ -n "$__fzf_bat" ]; then
  __fzf_file_preview="$__fzf_bat --color=always --style=numbers --line-range=:300 {}"
else
  __fzf_file_preview="head -300 {}"
fi
__fzf_dir_preview="tree -C -L 2 {} 2>/dev/null | head -200 || ls -la {}"
export FZF_CTRL_T_OPTS="--preview '[ -d {} ] && { $__fzf_dir_preview; } || $__fzf_file_preview' --bind 'ctrl-/:toggle-preview'"
export FZF_ALT_C_OPTS="--preview '$__fzf_dir_preview' --bind 'ctrl-/:toggle-preview'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind 'ctrl-/:toggle-preview'"

unset __fzf_fd __fzf_bat __fzf_fd_opts __fzf_file_preview __fzf_dir_preview
