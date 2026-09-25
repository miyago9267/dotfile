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

# 設定需要的最低版本（lazy.nvim 與 plugin 需求）
MIN_MINOR=10
LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"

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

nvim_minor() {
    nvim --version 2>/dev/null | head -n1 | sed -E 's/^NVIM v?0\.([0-9]+).*/\1/'
}

# 系統套件庫能直接提供新版 Neovim 的平台
has_modern_package() {
    case $OS in
        macos|arch|manjaro)
            return 0
            ;;
        ubuntu)
            [ "$(echo "$OS_VERSION" | cut -d. -f1)" -ge 22 ]
            ;;
        debian)
            [ "$(echo "$OS_VERSION" | cut -d. -f1)" -ge 12 ]
            ;;
        *)
            return 1
            ;;
    esac
}

# =====================
#   Portable build（舊系統）
# =====================
# neovim/neovim-releases 以 glibc 2.17 編譯，Ubuntu 16.04+ / CentOS 7+ 都能跑，
# 裝在 ~/.local 不需要 root。
install_neovim_portable() {
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            print_warning "No portable Neovim build for $(uname -m); use Vim instead"
            return 1
            ;;
    esac

    url="https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-${arch}.tar.gz"
    tmp_dir="$(mktemp -d)"
    print_info "Downloading portable Neovim ($arch, glibc 2.17 build)..."
    curl -fL "$url" -o "$tmp_dir/nvim.tar.gz"
    tar -xzf "$tmp_dir/nvim.tar.gz" -C "$tmp_dir"

    mkdir -p "$LOCAL_OPT" "$LOCAL_BIN"
    rm -rf "$LOCAL_OPT/nvim"
    mv "$tmp_dir/nvim-linux-${arch}" "$LOCAL_OPT/nvim"
    ln -sf "$LOCAL_OPT/nvim/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf "$tmp_dir"

    export PATH="$LOCAL_BIN:$PATH"
    print_info "Installed to $LOCAL_OPT/nvim (make sure $LOCAL_BIN is in PATH)"
}

# =====================
#   Install Neovim
# =====================
install_neovim() {
    if command -v nvim >/dev/null 2>&1; then
        current_version=$(nvim --version | head -n1 | awk '{print $2}')
        if [ "$(nvim_minor)" -lt "$MIN_MINOR" ] 2>/dev/null; then
            print_warning "Neovim $current_version is older than 0.$MIN_MINOR, upgrading..."
        else
            print_info "Neovim already installed: $current_version"
            read -p "Do you want to reinstall/upgrade? [y/N]: " choice
            case "$choice" in
                y|Y ) print_info "Proceeding with installation..." ;;
                * ) print_info "Skipping installation"; return 0 ;;
            esac
        fi
    fi

    print_info "Installing Neovim..."

    if has_modern_package; then
        case $OS in
            macos)
                brew install neovim
                ;;
            ubuntu|debian)
                sudo add-apt-repository -y ppa:neovim-ppa/unstable
                sudo apt-get update
                sudo apt-get install -y neovim
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm neovim
                ;;
        esac
    elif [ "$(uname)" = "Linux" ]; then
        install_neovim_portable || exit 0
    else
        echo "[WARN] Neovim 不支援當前 OS ($OS)，跳過"
        exit 0
    fi

    hash -r
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
# 舊系統的套件庫可能沒有這些套件，失敗時只警告不中斷
pkg_install() {
    case $OS in
        macos) brew install "$@" ;;
        ubuntu|debian) sudo apt-get install -y "$@" ;;
        arch|manjaro) sudo pacman -S --noconfirm "$@" ;;
        *) return 1 ;;
    esac
}

install_dependencies() {
    print_info "Installing dependencies..."

    # ripgrep（全域內容搜尋）
    if command -v rg >/dev/null 2>&1; then
        print_success "ripgrep already installed"
    elif pkg_install ripgrep; then
        print_success "ripgrep installed"
    else
        print_warning "ripgrep unavailable; Space fg falls back to grep"
    fi

    # fd（檔名搜尋；Debian/Ubuntu 套件名是 fd-find）
    if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
        print_success "fd already installed"
    else
        case $OS in
            ubuntu|debian) fd_pkg=fd-find ;;
            *) fd_pkg=fd ;;
        esac
        if pkg_install "$fd_pkg"; then
            print_success "fd installed"
        else
            print_warning "fd unavailable; file search falls back to find"
        fi
    fi

    # fzf（fzf-lua 需要較新的 fzf；舊系統套件太舊，改用官方 binary）
    if command -v fzf >/dev/null 2>&1; then
        print_success "fzf already installed"
    else
        print_info "Installing fzf binary..."
        if [ ! -d "$HOME/.fzf" ]; then
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        fi
        "$HOME/.fzf/install" --bin
        mkdir -p "$LOCAL_BIN"
        ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"
        print_success "fzf installed"
    fi

    # Node.js (for LSP servers)
    if command -v node >/dev/null 2>&1; then
        print_success "Node.js installed: $(node --version)"
    else
        print_warning "Node.js not found. Some LSP servers and Copilot will not work."
    fi

    # gcc/make (for building treesitter parsers)
    if command -v gcc >/dev/null 2>&1; then
        print_success "gcc installed"
    else
        print_warning "gcc not found. Installing build tools..."
        case $OS in
            macos) xcode-select --install 2>/dev/null || print_info "Xcode tools already installed" ;;
            ubuntu|debian) pkg_install build-essential || print_warning "build-essential unavailable" ;;
            arch|manjaro) pkg_install base-devel || print_warning "base-devel unavailable" ;;
        esac
    fi
}

# =====================
#   Main Installation
# =====================
main() {
    install_neovim
    install_dependencies

    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Start Neovim: nvim  (first run installs plugins; if issues occur: :Lazy sync)"
    echo "  2. Copilot (optional): :Copilot auth"
    echo ""
}

# Run main function
main
