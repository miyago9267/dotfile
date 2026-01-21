if [ -d "/usr/local/opt/gcc/bin" ]; then
  case ":$PATH:" in
    *":/usr/local/opt/gcc/bin:"*) ;;
    *) PATH="/usr/local/opt/gcc/bin:$PATH" ;;
  esac
fi
export PATH
