# Claude Code CLI (installed to ~/.local/bin via npm)
__zshrc_prepend_path_if_dir "$HOME/.local/bin"

# Shoal Jev route advisory (config/ai/shared/jev/README.md).
# Per-session override: SHOAL_JEV_MODE=shadow claude, or =off to disable.
export SHOAL_JEV_MODE="${SHOAL_JEV_MODE:-active}"
