# NVM lazy-load: only initialize when nvm/node/npm/npx is first called
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
_nvm_lazy_init() {
  unset -f nvm node npm npx
  if [ -r "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  elif [ -r "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    . "/opt/homebrew/opt/nvm/nvm.sh"
  else
    return 127
  fi
  [ -r "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}

# 把 nvm default 版本的 bin 放進 PATH，讓不經過 zsh function 的程序（agent hook 的
# /bin/sh、script、editor）也找得到 node。只讀 alias 檔與目錄，不 source nvm.sh。
_nvm_default_bin() {
  local ver=default i
  local -a dirs
  for i in 1 2 3 4; do
    [ -r "$NVM_DIR/alias/$ver" ] || break
    ver="$(<"$NVM_DIR/alias/$ver")"
  done
  ver="${ver#v}"
  case "$ver" in
    default|node|stable) dirs=("$NVM_DIR"/versions/node/v*(N/nOn)) ;;
    *) dirs=("$NVM_DIR"/versions/node/v$ver(N/) "$NVM_DIR"/versions/node/v$ver.*(N/nOn)) ;;
  esac
  [ -x "${dirs[1]}/bin/node" ] && print -r -- "${dirs[1]}/bin"
}

if [ -r "$NVM_DIR/nvm.sh" ] || [ -r "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"
  _nvm_bin="$(_nvm_default_bin)"
  if [ -n "$_nvm_bin" ] && (( ! ${path[(Ie)$_nvm_bin]} )); then
    path=("$_nvm_bin" $path)
  fi
  unset _nvm_bin
  unfunction _nvm_default_bin
  nvm()  { _nvm_lazy_init && nvm  "$@"; }
  node() { _nvm_lazy_init && node "$@"; }
  npm()  { _nvm_lazy_init && npm  "$@"; }
  npx()  { _nvm_lazy_init && npx  "$@"; }
fi
