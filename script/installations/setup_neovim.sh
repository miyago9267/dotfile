#!/bin/sh

echo "Neovim setup starting..."

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

install_package() {
    package=$1
    case $OS in
        macos)
            brew install "$package" 2>/dev/null || true
            ;;
        ubuntu|debian)
            sudo apt-get update -qq
            sudo apt-get install -y "$package" 2>/dev/null || true
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm "$package" 2>/dev/null || true
            ;;
        *)
            echo "Unsupported OS, please install manually: $package"
            return 1
            ;;
    esac
}

OS=$(detect_os)
echo "Detected OS: $OS"

# Check Neovim
if ! command -v nvim >/dev/null 2>&1; then
    echo "Error: Neovim not installed"
    echo "Install: brew install neovim (macOS) or apt install neovim (Linux)"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -n1 | cut -d' ' -f2)
echo "Neovim version: $NVIM_VERSION"

# Check dependencies
echo "Checking dependencies..."

# ripgrep (for Telescope)
if ! command -v rg >/dev/null 2>&1; then
    echo "Installing ripgrep..."
    install_package ripgrep
fi

# fd (for Telescope file finder)
if ! command -v fd >/dev/null 2>&1; then
    echo "Installing fd..."
    case $OS in
        macos)
            install_package fd
            ;;
        ubuntu|debian)
            install_package fd-find
            ;;
        arch|manjaro)
            install_package fd
            ;;
    esac
fi

# Node.js (for some LSP servers)
if ! command -v node >/dev/null 2>&1; then
    echo "Node.js not found. Some LSP features may not work."
    echo "Install: brew install node (macOS) or apt install nodejs (Linux)"
fi

# gcc/make (for building treesitter parsers)
if ! command -v gcc >/dev/null 2>&1; then
    echo "Warning: gcc not found. Treesitter may not work."
    case $OS in
        macos)
            echo "Install: xcode-select --install"
            ;;
        ubuntu|debian)
            echo "Install: sudo apt install build-essential"
            ;;
        arch|manjaro)
            echo "Install: sudo pacman -S base-devel"
            ;;
    esac
fi

echo ""
echo "Dependencies check complete"
echo ""
echo "Next steps:"
echo ""
echo "1. Setup AI Provider (choose one):"
echo ""
echo "   Option A: GitHub Copilot (recommended, already configured)"
echo "   Start Neovim: nvim"
echo "   Authenticate: :Copilot auth"
echo "   Follow the instructions"
echo ""
echo "   Option B: Claude or OpenAI"
echo "   Edit ~/dotfile/.env and add:"
echo "     AVANTE_ANTHROPIC_API_KEY='your-key'  # for Claude"
echo "     AVANTE_OPENAI_API_KEY='your-key'     # for OpenAI"
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
echo "   - clangd (C/C++)"
echo ""
echo "Setup complete!"
echo ""
