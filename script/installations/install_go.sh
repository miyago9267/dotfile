

#!/bin/bash
set -e

GO_VERSION="1.22.3"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_TAR}"

echo "🔧 安裝 Go ${GO_VERSION}..."
wget ${GO_URL}
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf ${GO_TAR}
rm ${GO_TAR}

# 加入 PATH
echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc
echo 'Go 安裝完成，請重新開啟終端或執行 source ~/.bashrc'