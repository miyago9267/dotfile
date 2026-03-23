# Set up Go environment
# Priority: use g if available, otherwise try brew, then fallback

if alias g >/dev/null 2>&1 && [[ "$(alias g)" == *"git"* ]]; then
  unalias g
fi

if command -v g &>/dev/null; then
  eval "$(g env)"
else
  # Try brew first
  if command -v brew &>/dev/null && brew list go &>/dev/null 2>&1; then
    export GOROOT="$(brew --prefix go)/libexec"
    export GOPATH="$HOME/go"
  else
    # Fallback based on OS
    case "$(uname -s)" in
      Darwin)
        export GOPATH="$HOME/go"
        export GOROOT="/usr/local/go"
        ;;
      Linux)
        export GOPATH="$HOME/go"
        if [ -f /etc/arch-release ]; then
          export GOROOT="/usr"
        else
          export GOROOT="/usr/local/go"
        fi
        ;;
      *)
        echo "Unsupported OS: $(uname -s)" >&2
        ;;
    esac
  fi

  # GOPATH/bin 可能尚未建立（第一次 go install 才會產生），主動建立確保 PATH 生效
  [ -n "$GOPATH" ] && mkdir -p "$GOPATH/bin" 2>/dev/null

  # Add to PATH
  for dir in "$GOROOT/bin" "$GOPATH/bin"; do
    __zshrc_prepend_path_if_dir "$dir"
  done
fi

export PATH
