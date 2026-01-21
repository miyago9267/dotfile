

#!/bin/bash
set -e

GO_VERSION="1.25"

OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

# Detect OS (macOS, Linux)
case "$OS_NAME" in
	Darwin)
		GO_OS="darwin"
		echo "Detected: macOS"
		;;
	Linux)
		GO_OS="linux"
		if [ -f /etc/arch-release ]; then
			echo "Detected: Arch Linux"
		elif [ -f /etc/debian_version ]; then
			echo "Detected: Ubuntu/Debian"
		else
			echo "Detected: Linux (generic)"
		fi
		;;
	*)
		echo "Error: Unsupported OS: $OS_NAME" >&2
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
		echo "Error: Unsupported architecture: $ARCH_NAME" >&2
		exit 1
		;;
esac

GO_TAR="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TAR}"

echo "🔧 Installing Go ${GO_VERSION} (${GO_OS}/${GO_ARCH})..."
curl -LO "$GO_URL"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_TAR"
rm "$GO_TAR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" go
fi

echo "🔧 Installing Go version manager g..."
curl -sSL https://git.io/g-install | sh -s -- --yes

echo "✅ Go and version manager installation complete, environment variables updated, reopen terminal to take effect"