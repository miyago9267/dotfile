#!/bin/bash
set -e
. "$(dirname "$0")/_platform.sh"

GO_VERSION="1.25"

platform_guard "Go" darwin linux
is_installed go && skip_installed "Go"

ARCH_NAME="$(uname -m)"
case "$_PLATFORM_OS" in
	Darwin) GO_OS="darwin" ;;
	Linux)  GO_OS="linux" ;;
esac

case "$ARCH_NAME" in
	x86_64|amd64)
		GO_ARCH="amd64"
		;;
	arm64|aarch64)
		GO_ARCH="arm64"
		;;
	*)
		echo "[WARN] Go 不支援當前架構 ($ARCH_NAME)，跳過"
		exit 0
		;;
esac

GO_TAR="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TAR}"

echo "🔧 Installing Go ${GO_VERSION} (${GO_OS}/${GO_ARCH})..."

# Create temp directory for download
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"
curl -LO "$GO_URL"

sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_TAR"

# Cleanup is handled by trap
cd "$OLDPWD"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" go
fi

echo "🔧 Installing Go version manager g..."
curl -sSL https://git.io/g-install | sh -s -- --yes

echo "✅ Go and version manager installation complete, environment variables updated, reopen terminal to take effect"