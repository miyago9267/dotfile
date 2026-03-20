PHP83_BIN_DIR="/opt/homebrew/opt/php@8.3/bin"
PHP83_SBIN_DIR="/opt/homebrew/opt/php@8.3/sbin"
__zshrc_prepend_path_if_dir "$PHP83_BIN_DIR"
__zshrc_prepend_path_if_dir "$PHP83_SBIN_DIR"
unset PHP83_BIN_DIR
unset PHP83_SBIN_DIR
export PATH
