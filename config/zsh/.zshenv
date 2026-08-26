# Ubuntu WSL runs compinit from /etc/zsh/zshrc before ~/.zshrc.
case "$(uname -s)" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      skip_global_compinit=1
    fi
    ;;
esac
