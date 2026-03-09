PNPM_HOME_CANDIDATES=(
  "$HOME/.local/share/pnpm"
  "$HOME/Library/pnpm"
)

for pnpm_home_dir in "${PNPM_HOME_CANDIDATES[@]}"; do
  __zshrc_prepend_path_if_dir "$pnpm_home_dir"
done

if [ -d "$HOME/.local/share/pnpm" ]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
elif [ -d "$HOME/Library/pnpm" ]; then
  export PNPM_HOME="$HOME/Library/pnpm"
fi

unset pnpm_home_dir
unset PNPM_HOME_CANDIDATES
export PATH
