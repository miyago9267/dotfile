# Codex daily entrypoints. Keep raw `codex` untouched for desktop/TUI state.

function cxf() {
  command codex exec --ignore-user-config -p fast "$@"
}

function cxc() {
  command codex exec --ignore-user-config -p code "$@"
}

function cxh() {
  command codex exec -p heavy "$@"
}

function cxt() {
  command "$HOME/.codex/coralline/bin/coralline-codex-inject" "$@"
}

alias cxe='cxc'
alias codex-fast='cxf'
alias codex-code='cxc'
alias codex-heavy='cxh'
alias codex-coralline='cxt'
