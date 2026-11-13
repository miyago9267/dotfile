# k8s（dotfile script/utils/k8s）的 Tab 補全：子指令附說明，deploy / configmap 名稱從目前 namespace 撈
command -v k8s >/dev/null 2>&1 || return 0

_k8s() {
  local -a subs
  subs=(
    'ctx:切 context'
    'ns:切 namespace'
    'pods:列 pod（可過濾）'
    'logs:追 log'
    'sh:進 container 開 shell'
    'restart:rollout restart 並等完成'
    'env:列出讀的 configmap / secret 與 key'
    'keys:比對 secret 的 key'
    'rotate:新增或輪替一個 secret key（值從 stdin）'
    'hist:rollout / 事件 / ArgoCD git / SM 版本'
    'cm:改 configmap（ArgoCD 管的開 repo 原始檔）'
    'help:顯示說明'
  )
  if (( CURRENT == 2 )); then
    _describe 'k8s 子指令' subs
    return
  fi
  case "$words[2]" in
    ctx) compadd -- $(command kubectl config get-contexts -o name 2>/dev/null) ;;
    ns) compadd -- $(command kubectl get ns -o name 2>/dev/null | sed 's|^.*/||') ;;
    logs|sh|restart|env|keys|hist|rotate)
      (( CURRENT == 3 )) && compadd -- $(command kubectl get deploy -o name 2>/dev/null | sed 's|^.*/||') ;;
    cm) compadd -- $(command kubectl get configmap -o name 2>/dev/null | sed 's|^.*/||') ;;
  esac
}
compdef _k8s k8s
