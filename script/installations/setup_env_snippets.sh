#!/bin/sh
set -e

ZSHRC_D="$HOME/.zshrc.d"
mkdir -p "$ZSHRC_D"

log_snippet() {
  printf '→ Updated %s\n' "$1"
}

ALL_SNIPPETS="system zplug nvm python go rust pnpm bun flutter android gcloud php83 fvm vscode_cli gcc"

if [ "$#" -gt 0 ]; then
  TARGETS="$*"
else
  TARGETS="$ALL_SNIPPETS"
fi

for name in $TARGETS; do
  case "$name" in
    system|system_base)
      cat <<'EOF' > "$ZSHRC_D/system_path.zsh"
__zshrc_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games /snap/bin; do
  [ -d "$dir" ] || continue
  __zshrc_prepend_path "$dir"
done
unset -f __zshrc_prepend_path
export PATH
EOF
      log_snippet "system_path.zsh"
      ;;
    zplug)
      cat <<'EOF' > "$ZSHRC_D/zplug.zsh"
for dir in "$HOME/.zplug/repos/zplug/zplug/bin" "$HOME/.zplug/bin"; do
  [ -d "$dir" ] || continue
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
done
export PATH
EOF
      log_snippet "zplug.zsh"
      ;;
    nvm)
      cat <<'EOF' > "$ZSHRC_D/nvm.zsh"
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
fi
if [ -s "$NVM_DIR/bash_completion" ]; then
  . "$NVM_DIR/bash_completion"
fi
EOF
      log_snippet "nvm.zsh"
      ;;
    python)
      cat <<'EOF' > "$ZSHRC_D/python.zsh"
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  case ":$PATH:" in
    *":$PYENV_ROOT/bin:"*) ;;
    *) PATH="$PYENV_ROOT/bin:$PATH" ;;
  esac
  case ":$PATH:" in
    *":$PYENV_ROOT/shims:"*) ;;
    *) PATH="$PYENV_ROOT/shims:$PATH" ;;
  esac
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
  elif [ -x "$PYENV_ROOT/bin/pyenv" ]; then
    eval "$($PYENV_ROOT/bin/pyenv init -)"
  fi
fi
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
EOF
      log_snippet "python.zsh"
      ;;
    go)
      cat <<'EOF' > "$ZSHRC_D/go.zsh"
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"
for dir in "$GOROOT/bin" "$GOPATH/bin"; do
  [ -d "$dir" ] || continue
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
done
export PATH
EOF
      log_snippet "go.zsh"
      ;;
    rust)
      cat <<'EOF' > "$ZSHRC_D/rust.zsh"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
EOF
      log_snippet "rust.zsh"
      ;;
    pnpm)
      cat <<'EOF' > "$ZSHRC_D/pnpm.zsh"
export PNPM_HOME="$HOME/.local/share/pnpm"
if [ -d "$PNPM_HOME" ]; then
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) PATH="$PNPM_HOME:$PATH" ;;
  esac
fi
export PATH
EOF
      log_snippet "pnpm.zsh"
      ;;
    bun)
      cat <<'EOF' > "$ZSHRC_D/bun.zsh"
export BUN_INSTALL="$HOME/.bun"
if [ -d "$BUN_INSTALL/bin" ]; then
  case ":$PATH:" in
    *":$BUN_INSTALL/bin:"*) ;;
    *) PATH="$BUN_INSTALL/bin:$PATH" ;;
  esac
fi
[ -s "$BUN_INSTALL/_bun" ] && . "$BUN_INSTALL/_bun"
export PATH
EOF
      log_snippet "bun.zsh"
      ;;
    flutter)
      cat <<'EOF' > "$ZSHRC_D/flutter.zsh"
if [ -d "$HOME/development/flutter/bin" ]; then
  case ":$PATH:" in
    *":$HOME/development/flutter/bin:"*) ;;
    *) PATH="$HOME/development/flutter/bin:$PATH" ;;
  esac
fi
export PATH
EOF
      log_snippet "flutter.zsh"
      ;;
    android)
      cat <<'EOF' > "$ZSHRC_D/android.zsh"
__zshrc_detect_android_home() {
  if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
    printf '%s' "$ANDROID_HOME"
    return
  fi
  if [ -d "$HOME/Library/Android/sdk" ]; then
    printf '%s' "$HOME/Library/Android/sdk"
    return
  fi
  if [ -d "$HOME/Android/Sdk" ]; then
    printf '%s' "$HOME/Android/Sdk"
    return
  fi
  case "$(uname -s)" in
    Darwin)
      printf '%s' "$HOME/Library/Android/sdk"
      ;;
    *)
      printf '%s' "$HOME/Android/Sdk"
      ;;
  esac
}
ANDROID_HOME="$(__zshrc_detect_android_home)"
unset -f __zshrc_detect_android_home
if [ -d "$ANDROID_HOME" ]; then
  for dir in "$ANDROID_HOME/cmdline-tools/latest/bin" "$ANDROID_HOME/platform-tools"; do
    [ -d "$dir" ] || continue
    case ":$PATH:" in
      *":$dir:"*) ;;
      *) PATH="$dir:$PATH" ;;
    esac
  done
fi
export ANDROID_HOME
export PATH
EOF
      log_snippet "android.zsh"
      ;;
    gcloud)
      cat <<'EOF' > "$ZSHRC_D/gcloud.zsh"
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/completion.zsh.inc"
fi
EOF
      log_snippet "gcloud.zsh"
      ;;
    php83)
      cat <<'EOF' > "$ZSHRC_D/php83.zsh"
if [ -d "/opt/homebrew/opt/php@8.3/bin" ]; then
  case ":$PATH:" in
    *":/opt/homebrew/opt/php@8.3/bin:"*) ;;
    *) PATH="/opt/homebrew/opt/php@8.3/bin:$PATH" ;;
  esac
fi
if [ -d "/opt/homebrew/opt/php@8.3/sbin" ]; then
  case ":$PATH:" in
    *":/opt/homebrew/opt/php@8.3/sbin:"*) ;;
    *) PATH="/opt/homebrew/opt/php@8.3/sbin:$PATH" ;;
  esac
fi
export PATH
EOF
      log_snippet "php83.zsh"
      ;;
    fvm)
      cat <<'EOF' > "$ZSHRC_D/fvm.zsh"
for dir in "$HOME/fvm/bin" "$HOME/.pub-cache/bin"; do
  [ -d "$dir" ] || continue
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
done
export PATH
EOF
      log_snippet "fvm.zsh"
      ;;
    vscode_cli)
      cat <<'EOF' > "$ZSHRC_D/vscode_remote_cli.zsh"
__zshrc_add_vscode_remote_cli_paths() {
  setopt local_options null_glob
  for remote_cli_dir in "$HOME"/.vscode-server/cli/servers/*/server/bin/remote-cli; do
    [ -d "$remote_cli_dir" ] || continue
    case ":$PATH:" in
      *":$remote_cli_dir:"*) ;;
      *) PATH="$remote_cli_dir:$PATH" ;;
    esac
  done
  unset remote_cli_dir
}
__zshrc_add_vscode_remote_cli_paths
unset -f __zshrc_add_vscode_remote_cli_paths
export PATH
EOF
      log_snippet "vscode_remote_cli.zsh"
      ;;
    gcc)
      cat <<'EOF' > "$ZSHRC_D/gcc.zsh"
if [ -d "/usr/local/opt/gcc/bin" ]; then
  case ":$PATH:" in
    *":/usr/local/opt/gcc/bin:"*) ;;
    *) PATH="/usr/local/opt/gcc/bin:$PATH" ;;
  esac
fi
export PATH
EOF
      log_snippet "gcc.zsh"
      ;;
    *)
      echo "Unknown snippet: $name" >&2
      exit 1
      ;;
  esac
done
