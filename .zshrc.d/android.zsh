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
