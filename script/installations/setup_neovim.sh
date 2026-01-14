#!/bin/sh
# Neovim 進階配置安裝腳本
# 整合 mars.nvim 和 avante.nvim 功能
# 支援 macOS, Ubuntu/Debian, Arch Linux

echo "開始配置 Neovim 進階功能..."

# 偵測作業系統
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ "$(uname)" = "Darwin" ]; then
        OS="macos"
    else
        OS="unknown"
    fi
    echo "$OS"
}

# 安裝套件的函數
install_package() {
    package=$1
    case $OS in
        macos)
            brew install "$package"
            ;;
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y "$package"
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm "$package"
            ;;
        *)
            echo "不支援的作業系統，請手動安裝: $package"
            return 1
            ;;
    esac
}

OS=$(detect_os)
echo "偵測到作業系統: $OS"

# 檢查 Neovim 版本
if ! command -v nvim >/dev/null 2>&1; then
    echo "錯誤: Neovim 未安裝"
    echo "請先安裝 Neovim 0.10 或更新版本"
    case $OS in
        macos)
            echo "  macOS: brew install neovim"
            ;;
        ub備份現有配置到: $BACKUP_FILE"
    cp "$NVIM_CONFIG" "$BACKUP_FILE"
fi

echo ""
echo "依賴檢查完成"
echo ""
echo "========================================"
echo "後續步驟:"
echo "========================================"
echo ""
echo "1. 設定 AI Provider:"
echo ""
echo "   選項 A: 使用 GitHub Copilot (已預設，推薦)"
echo "   ----------------------------------------"
echo "   如果你有 GitHub Copilot 訂閱:"
echo "   1) 啟動 Neovim: nvim"
echo "   2) 執行認證: :Copilot auth"
echo "   3) 依照指示完成驗證"
echo ""
echo "   不需要設定額外的 API key！"
echo ""
echo "   選項 B: 使用 Claude 或 OpenAI"
echo "   ----------------------------------------"
echo "   編輯 ~/dotfile/.env 並加入:"
echo "   AVANTE_ANTHROPIC_API_KEY='your-key'  # Claude"
echo "   或"
echo "   AVANTE_OPENAI_API_KEY='your-key'     # OpenAI"
echo ""
echo "   然後修改 ~/.config/nvim/init.lua 中的 provider"
echo ""
echo "   重新載入: source ~/.zshrc"
echo ""
echo "----------------------------------------"
echo ""
echo "2. 啟動 Neovim:"
echo "   nvim"
echo ""
echo "   首次啟動會自動下載並安裝所有插件"
echo "   如遇問題可執行: :Lazy sync"
echo ""
echo "----------------------------------------"
echo ""
echo "3. 安裝 LSP 伺服器 (在 Neovim 中執行):"
echo "   :Mason"
echo ""
echo "   建議安裝的 LSP:"
echo "   - lua_ls (Lua)"
echo "   - tsserver (TypeScript/JavaScript)"
echo "   - pyright (Python)"
echo "   - gopls (Go)"
echo "   - clangd (C/C++)"
echo ""
echo "----------------------------------------"
echo ""
echo "4. 查看完整使用文件:"
echo "   cat ~/dotfile/NEOVIM_UPGRADE.md"
echo "   cat ~/dotfile/NEOVIM_KEYBINDINGS.md"
echo ""
echo "========================================"
echo ""
echo "主要新功能:"
echo ""
echo "  AI 輔助編程 (Avante.nvim)"
echo "    <leader>aa - 詢問 AI"
echo "    <leader>ae - AI 編輯程式碼"
echo ""
echo "  模糊搜尋 (Telescope)"
echo "    <C-p> - 快速尋找檔案"
echo "    <leader>sg - 全域搜尋"
echo ""
echo "  快速跳轉 (Leap)"
echo "    s + 字元 - 跳轉到任意位置"
echo ""
echo "  Git 整合 (Neogit)"
echo "    <leader>ng - 開啟 Git 介面"
echo ""
echo "  提示: 按下 <Space> 會顯示所有可用快捷鍵"
echo ""
echo "========================================"
echo ""
echo "Neovim 進階配置完成"
echo ""
echo "你的原有配置已完整保留:"
echo "  - .vimrc 繼續運作"
echo "  - NERDTree (F4) 保持不變"
echo "  - coc.nvim 繼續可用"
echo "  - 所有原有快捷鍵無衝突"
echo ""
if [ -n "$BACKUP_FILE" ]; then
    echo "如需還原: mv $BACKUP_FILE $NVIM_CONFIG"
fiild-essential"
            ;;
        arch|manjaro)
            echo "  請安裝: sudo pacman -S base-devel"
            ;;
    esac
fi

# 備份現有配置
NVIM_CONFIG="$HOME/.config/nvim/init.lua"
if [ -f "$NVIM_CONFIG" ]; then
    BACKUP_FILE="$NVIM_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
    echo ""
    echo "📝 備份現有配置到: $BACKUP_FILE"
    cp "$NVIM_CONFIG" "$BACKUP_FILE"
fi

echo ""
echo "✅ 依賴檢查完成！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 後續步驟:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  設定 AI API 金鑰 (選擇其中一個):"
echo ""
echo "   使用 Claude (推薦):"
echo "   export AVANTE_ANTHROPIC_API_KEY='your-api-key'"
echo ""
echo "   或使用 OpenAI:"
echo "   export AVANTE_OPENAI_API_KEY='your-api-key'"
echo ""
echo "   或使用 GitHub Copilot (若已訂閱):"
echo "   # 在 init.lua 中設定 provider = \"copilot\""
echo ""
echo "   💡 建議將環境變數加入 ~/.zshrc:"
echo "   echo 'export AVANTE_ANTHROPIC_API_KEY=\"your-key\"' >> ~/.zshrc"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "2️⃣  啟動 Neovim:"
echo "   nvim"
echo ""
echo "   ⏳ 首次啟動會自動下載並安裝所有插件"
echo "   📦 如遇問題可執行: :Lazy sync"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "3️⃣  安裝 LSP 伺服器 (在 Neovim 中執行):"
echo "   :Mason"
echo ""
echo "   建議安裝的 LSP:"
echo "   • lua_ls (Lua)"
echo "   • tsserver (TypeScript/JavaScript)"
echo "   • pyright (Python)"
echo "   • gopls (Go)"
echo "   • clangd (C/C++)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "4️⃣  查看完整使用文件:"
echo "   cat ~/dotfile/NEOVIM_UPGRADE.md"
echo "   cat ~/dotfile/NEOVIM_KEYBINDINGS.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 主要新功能:"
echo ""
echo "  🤖 AI 輔助編程 (Avante.nvim)"
echo "     <leader>aa - 詢問 AI"
echo "     <leader>ae - AI 編輯程式碼"
echo ""
echo "  🔍 模糊搜尋 (Telescope)"
echo "     <C-p> - 快速尋找檔案"
echo "     <leader>sg - 全域搜尋"
echo ""
echo "  ⚡ 快速跳轉 (Leap)"
echo "     s + 字元 - 跳轉到任意位置"
echo ""
echo "  🌿 Git 整合 (Neogit)"
echo "     <leader>ng - 開啟 Git 介面"
echo ""
echo "  💡 提示: 按下 <Space> 會顯示所有可用快捷鍵"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 Neovim 進階配置完成！"
echo ""
echo "⚠️  你的原有配置已完整保留:"
echo "   • .vimrc 繼續運作"
echo "   • NERDTree (F4) 保持不變"
echo "   • coc.nvim 繼續可用"
echo "   • 所有原有快捷鍵無衝突"
echo ""
echo "🆘 如需還原: mv $BACKUP_FILE $NVIM_CONFIG"
echo ""
