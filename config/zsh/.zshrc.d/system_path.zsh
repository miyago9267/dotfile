for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games /snap/bin; do
  __zshrc_prepend_path_if_dir "$dir"
done
export PATH
