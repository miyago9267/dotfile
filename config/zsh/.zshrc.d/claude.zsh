# Claude Code CLI (installed to ~/.local/bin via npm)
__zshrc_prepend_path_if_dir "$HOME/.local/bin"

# Pilotfish Jev route advisory (config/ai/shared/jev/README.md).
# Per-session override: PILOTFISH_JEV_MODE=shadow claude, or =off to disable.
export PILOTFISH_JEV_MODE="${PILOTFISH_JEV_MODE:-active}"
