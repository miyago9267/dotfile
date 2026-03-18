#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║        Neovim Installation & Setup             ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# =====================
#   OS Detection
# =====================
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ "$(uname)" = "Darwin" ]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
    else
        OS="unknown"
        OS_VERSION=""
    fi
}

detect_os
print_info "Detected OS: $OS $OS_VERSION"

# =====================
#   Version Check
# =====================
check_system_capability() {
    # 檢查系統是否支援 Neovim 11+
    case $OS in
        macos)
            # macOS 通常都支援最新版
            return 0
            ;;
        ubuntu|debian)
            # Ubuntu 22.04+ 和 Debian 12+ 支援
            major_version=$(echo "$OS_VERSION" | cut -d. -f1)
            if [ "$OS" = "ubuntu" ] && [ "$major_version" -ge 22 ]; then
                return 0
            elif [ "$OS" = "debian" ] && [ "$major_version" -ge 12 ]; then
                return 0
            else
                return 1
            fi
            ;;
        arch|manjaro)
            # Arch 系列通常都支援最新版
            return 0
            ;;
        *)
            # 未知系統,保守起見使用舊版
            return 1
            ;;
    esac
}

# =====================
#   Install Neovim
# =====================
install_neovim() {
    if command -v nvim >/dev/null 2>&1; then
        current_version=$(nvim --version | head -n1 | awk '{print $2}')
        print_info "Neovim already installed: $current_version"
        
        # 詢問是否要重新安裝
        read -p "Do you want to reinstall/upgrade? [y/N]: " choice
        case "$choice" in 
            y|Y ) 
                print_info "Proceeding with installation..."
                ;;
            * ) 
                print_info "Skipping installation"
                return 0
                ;;
        esac
    fi
    
    print_info "Installing Neovim..."
    
    if check_system_capability; then
        print_info "System supports Neovim 11+, installing latest version..."
        USE_LATEST=true
        
        case $OS in
            macos)
                brew install neovim
                ;;
            ubuntu|debian)
                # 使用 unstable PPA 或 AppImage
                print_info "Installing from unstable PPA..."
                sudo add-apt-repository -y ppa:neovim-ppa/unstable
                sudo apt-get update
                sudo apt-get install -y neovim
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm neovim
                ;;
        esac
    else
        print_warning "System may not support Neovim 11+, installing stable version 0.9/0.10..."
        USE_LATEST=false
        
        case $OS in
            ubuntu|debian)
                # 使用 stable PPA
                sudo add-apt-repository -y ppa:neovim-ppa/stable
                sudo apt-get update
                sudo apt-get install -y neovim
                ;;
            *)
                print_error "Cannot install older version automatically on this OS"
                print_info "Please install Neovim 0.9 or 0.10 manually"
                exit 1
                ;;
        esac
    fi
    
    if command -v nvim >/dev/null 2>&1; then
        installed_version=$(nvim --version | head -n1 | awk '{print $2}')
        print_success "Neovim installed: $installed_version"
    else
        print_error "Neovim installation failed"
        exit 1
    fi
}

# =====================
#   Install Dependencies
# =====================
install_dependencies() {
    print_info "Installing dependencies..."
    
    # ripgrep (for Telescope)
    if ! command -v rg >/dev/null 2>&1; then
        print_info "Installing ripgrep..."
        case $OS in
            macos)
                brew install ripgrep
                ;;
            ubuntu|debian)
                sudo apt-get install -y ripgrep
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm ripgrep
                ;;
        esac
        print_success "ripgrep installed"
    else
        print_success "ripgrep already installed"
    fi
    
    # fd (for Telescope file finder)
    if ! command -v fd >/dev/null 2>&1; then
        print_info "Installing fd..."
        case $OS in
            macos)
                brew install fd
                ;;
            ubuntu|debian)
                sudo apt-get install -y fd-find
                # 建立 symlink
                sudo ln -sf $(which fdfind) /usr/local/bin/fd 2>/dev/null || true
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm fd
                ;;
        esac
        print_success "fd installed"
    else
        print_success "fd already installed"
    fi
    
    # Node.js (for LSP servers)
    if ! command -v node >/dev/null 2>&1; then
        print_warning "Node.js not found. Some LSP features may not work."
        print_info "Install with: brew install node (macOS) or apt install nodejs (Linux)"
    else
        node_version=$(node --version)
        print_success "Node.js installed: $node_version"
    fi
    
    # gcc/make (for building treesitter parsers)
    if ! command -v gcc >/dev/null 2>&1; then
        print_warning "gcc not found. Installing build tools..."
        case $OS in
            macos)
                xcode-select --install 2>/dev/null || print_info "Xcode tools already installed"
                ;;
            ubuntu|debian)
                sudo apt-get install -y build-essential
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm base-devel
                ;;
        esac
    else
        print_success "gcc installed"
    fi
}

# =====================
#   Configure Neovim
# =====================
configure_neovim() {
    print_info "Configuring Neovim..."
    
    nvim_version=$(nvim --version | head -n1 | awk '{print $2}')
    major_version=$(echo "$nvim_version" | cut -d. -f2)  # 0.11 -> 11
    
    # 檢查是否需要建立相容性設定
    if [ "$major_version" -lt 11 ]; then
        print_warning "Neovim version < 0.11 detected, creating compatibility config..."
        
        # 建立相容性設定檔
        compat_file="$HOME/dotfile/nvim/lua/compat.lua"
        mkdir -p "$(dirname "$compat_file")"
        
        cat > "$compat_file" <<'EOF'
-- Compatibility layer for Neovim < 0.11
local M = {}

-- 檢測 Neovim 版本
local function get_nvim_version()
    local version = vim.version()
    return version.major * 100 + version.minor
end

M.nvim_version = get_nvim_version()
M.is_nvim_011_or_later = M.nvim_version >= 11

-- LSP 設定相容層
M.setup_lsp = function()
    local lspconfig = require('lspconfig')
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    
    if M.is_nvim_011_or_later then
        -- Neovim 0.11+ 使用新 API
        vim.lsp.config('*', {
            capabilities = capabilities,
        })
        vim.lsp.enable({ 'lua_ls', 'ts_ls', 'pyright', 'gopls' })
    else
        -- Neovim 0.10- 使用舊 API
        local servers = { 'lua_ls', 'ts_ls', 'pyright', 'gopls' }
        for _, lsp in ipairs(servers) do
            lspconfig[lsp].setup({
                capabilities = capabilities,
            })
        end
    end
end

return M
EOF
        
        # 修改 init.lua 以使用相容層
        init_file="$HOME/dotfile/nvim/init.lua"
        if [ -f "$init_file" ]; then
            # 備份原始檔案
            cp "$init_file" "$init_file.backup.$(date +%Y%m%d_%H%M%S)"
            
            # 使用 sed 替換 LSP 設定部分
            # 這裡我們建立一個標記,讓使用者知道需要手動調整
            print_warning "Original init.lua backed up"
            print_warning "Please update LSP config in init.lua to use: require('compat').setup_lsp()"
        fi
        
        print_success "Compatibility config created at: $compat_file"
    else
        print_success "Neovim 0.11+ detected, using modern API"
    fi
}

# =====================
#   Main Installation
# =====================
main() {
    install_neovim
    install_dependencies
    configure_neovim
    
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "1. Setup AI Provider (choose one):"
    echo ""
    echo "   Option A: GitHub Copilot (recommended)"
    echo "   Start Neovim: nvim"
    echo "   Authenticate: :Copilot auth"
    echo ""
    echo "   Option B: Claude or OpenAI"
    echo "   Edit ~/dotfile/.env and add:"
    echo "     AVANTE_ANTHROPIC_API_KEY='your-key'"
    echo "     AVANTE_OPENAI_API_KEY='your-key'"
    echo "   Then reload: source ~/.zshrc"
    echo ""
    echo "2. Start Neovim:"
    echo "   nvim"
    echo ""
    echo "   First run will install all plugins automatically"
    echo "   If issues occur: :Lazy sync"
    echo ""
    echo "3. Install LSP servers (run in Neovim):"
    echo "   :Mason"
    echo ""
    echo "   Recommended LSPs:"
    echo "   - lua_ls (Lua)"
    echo "   - ts_ls (TypeScript/JavaScript)"
    echo "   - pyright (Python)"
    echo "   - gopls (Go)"
    echo ""
    
    nvim_version=$(nvim --version | head -n1 | awk '{print $2}')
    major_version=$(echo "$nvim_version" | cut -d. -f2)
    
    if [ "$major_version" -lt 11 ]; then
        echo ""
        print_warning "IMPORTANT: Neovim < 0.11 detected"
        print_info "Compatibility layer created at: ~/dotfile/nvim/lua/compat.lua"
        print_info "Update your LSP config to use: require('compat').setup_lsp()"
    fi
    
    echo ""
}

# Run main function
main
