#!/bin/sh

case "${PILOTFISH_JEV_MODE-}" in
  active|shadow) ;;
  *) exit 0 ;;
esac
exec python3 "$HOME/dotfile/config/ai/shared/jev/pilotfish_route.py"
