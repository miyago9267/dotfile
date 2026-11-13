# k: kubectl；kx: 切 context；kn: 切 namespace（不帶參數時用 fzf 挑，`kx -`/`kn -` 切回上一個）
command -v kubectl >/dev/null 2>&1 || return 0
alias k=kubectl
command -v kubectx >/dev/null 2>&1 && alias kx=kubectx
command -v kubens >/dev/null 2>&1 && alias kn=kubens
