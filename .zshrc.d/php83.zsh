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
