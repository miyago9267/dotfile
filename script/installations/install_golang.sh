

#!/bin/bash
set -e

GO_VERSION="1.24"

OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

case "$OS_NAME" in
	Darwin)
		GO_OS="darwin"
		;;
	Linux)
		GO_OS="linux"
		;;
	*)
		echo "❌ Unsupported OS: $OS_NAME" >&2
		exit 1
		;;
esac

case "$ARCH_NAME" in
	x86_64|amd64)
		GO_ARCH="amd64"
		;;
	arm64|aarch64)
		GO_ARCH="arm64"
		;;
	*)
		echo "❌ Unsupported architecture: $ARCH_NAME" >&2
		exit 1
		;;
esac

GO_TAR="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TAR}"

echo "🔧 安裝 Go ${GO_VERSION} (${GO_OS}/${GO_ARCH})..."
curl -LO "$GO_URL"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_TAR"
rm "$GO_TAR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" go
fi

echo "✅ Go 安裝完成，環境變數已更新，重新開啟終端即可生效"