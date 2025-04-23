

#!/bin/bash
set -e

echo "🔧 安裝 Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y

# 將 cargo/bin 加入 PATH
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
echo 'Rust 安裝完成，請重新開啟終端或執行 source ~/.bashrc'