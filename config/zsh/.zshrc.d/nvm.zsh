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

if [ -r "$NVM_DIR/nvm.sh" ] || [ -r "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"
  nvm()  { _nvm_lazy_init && nvm  "$@"; }
  node() { _nvm_lazy_init && node "$@"; }
  npm()  { _nvm_lazy_init && npm  "$@"; }
  npx()  { _nvm_lazy_init && npx  "$@"; }
fi
