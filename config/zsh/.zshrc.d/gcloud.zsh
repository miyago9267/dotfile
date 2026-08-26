if [ -x "$HOME/google-cloud-sdk/bin/gcloud" ] || command -v gcloud >/dev/null 2>&1; then
  [ -r "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
  [ -r "$HOME/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/google-cloud-sdk/completion.zsh.inc"
fi
