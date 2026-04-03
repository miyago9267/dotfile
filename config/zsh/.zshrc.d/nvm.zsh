# NVM lazy-load: only initialize when nvm/node/npm/npx is first called
export NVM_DIR="$HOME/.nvm"

_nvm_lazy_init() {
  unset -f nvm node npm npx
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    . "/opt/homebrew/opt/nvm/nvm.sh"
  fi
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}

nvm()  { _nvm_lazy_init; nvm  "$@"; }
node() { _nvm_lazy_init; node "$@"; }
npm()  { _nvm_lazy_init; npm  "$@"; }
npx()  { _nvm_lazy_init; npx  "$@"; }
