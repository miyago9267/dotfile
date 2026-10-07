#!/bin/sh

case "${SHOAL_JEV_MODE-}" in
  active|shadow) ;;
  *) exit 0 ;;
esac
exec python3 "$HOME/dotfile/config/ai/shared/jev/shoal_route.py"
