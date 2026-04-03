# Dotfile

Personal development environment setup for Vim, Neovim, and Tmux.

## Quick Start

1. Clone this repo.
2. `cd` to `dotfile` folder
3. **remove the safe in `setup.sh`** and run `setup.sh`

> Warning! This script will modified your setting, please use after thinking.
> I'm not responsible for any damage caused by this script

```shell
git clone https://github.com/miyago9267/dotfile.git && cd dotfile
sh setup.sh
```

## Supported Systems

- macOS (Darwin)
- Ubuntu/Debian (APT)
- Arch Linux (Pacman)
- **Windows (PowerShell 7+)** -- 見 [`powershell/README.md`](powershell/README.md)

## Features

### Vim (.vimrc)

- NERDTree file explorer
- Lightline status bar
- ALE linting and fixing
- Syntax highlighting for multiple languages
- VSCode-style keybindings
- Auto-completion with CoC

### Neovim (nvim/init.lua)

- Lazy.nvim plugin manager
- LSP support (Lua, TypeScript, Python, Go)
- Telescope fuzzy finder
- Avante.nvim AI assistant with GitHub Copilot
- Treesitter syntax highlighting
- Git integration (Gitsigns, Neogit)
- Tmux integration with seamless navigation
- VSCode-style editing features

### Tmux

- Custom key bindings
- Neovim integration via vim-tmux-navigator
- Prefix key: Ctrl-b (or Ctrl-a)

## File Structure

```tree
.
├── nvim/                  # Neovim 配置（跨平台共用）
│   ├── init.lua
│   ├── lua/
│   └── lazy-lock.json
├── powershell/            # Windows PowerShell 版
│   ├── profile.ps1        # 主 profile
│   ├── profile.d/         # 模組化載入
│   ├── setup.ps1          # 互動式安裝
│   └── setup.d/           # 安裝腳本
├── script/
│   ├── common/            # 跨平台安裝腳本
│   ├── linux/             # Linux 專用腳本
│   └── utils/
├── tmux/
│   ├── base.conf
│   └── nvim-extension.conf
├── .zshrc                 # Zsh 主設定
├── .zshrc.d/              # Zsh 模組化載入
├── alias.sh               # Shell 別名
├── .vimrc                 # Vim 設定
├── setup.sh               # macOS/Linux 互動式安裝
└── README.md
```

## Key Bindings

### Neovim Specific

Leader Key: Space

#### Telescope (Fuzzy Finder)

- `Ctrl-p` - Find files
- `<leader>sf` - Search files
- `<leader>sg` - Search by grep
- `<leader>sb` - Search buffers
- `<leader>sh` - Search help tags

#### Avante AI Assistant

- `<leader>aa` - Ask AI
- `<leader>ae` - Edit with AI
- `<leader>at` - Toggle AI panel
- `<leader>ar` - Refresh AI response

#### Navigation

- `s` - Leap forward
- `S` - Leap backward
- `gs` - Leap from window
- `Ctrl-h/j/k/l` - Navigate between Neovim and Tmux panes

#### LSP

- `gd` - Go to definition
- `gr` - Go to references
- `gi` - Go to implementation
- `K` - Hover documentation
- `<leader>rn` - Rename symbol
- `<leader>ca` - Code action

#### Git

- `<leader>ng` - Open Neogit
- `<leader>gs` - Grug-far search and replace

### VSCode-Style Keybindings (Both Vim and Neovim)

#### Line Movement

- `Alt-Up` - Move line up
- `Alt-Down` - Move line down

#### Commenting

- `Ctrl-/` - Toggle comment (Linux/Windows)
- `Cmd-/` - Toggle comment (macOS)

#### Smart Cursor

- `j/k` - Smart movement with boundary detection

### Common Keybindings (Both Vim and Neovim)

#### File Management

- `F4` - Toggle file explorer
- `Ctrl-s` - Save file
- `Ctrl-w` - Close buffer

#### Compilation (Vim)

- `F9/F10` - Compile and run C++
- `F7/F8` - Run Python

### Tmux Specific

Prefix Key: Ctrl-b (or Ctrl-a)

#### Tmux Navigation

- `Prefix + h/j/k/l` - Switch panes (when not in Neovim)
- `Ctrl-h/j/k/l` - Seamless navigation between Neovim and Tmux

## How it works

### macOS / Linux

1. Detect operating system (macOS/Ubuntu/Arch)
2. Install system packages via package manager
3. Download and setup plugins
4. Configure Vim, Neovim, and Tmux
5. Link configuration files to home directory
6. Install language runtimes (optional)

### Windows

1. Install PowerShell 7+ and Windows Terminal
2. Run `pwsh powershell/setup.ps1`
3. Select components to install (scoop, Neovim, oh-my-posh, etc.)
4. Configuration is symlinked or copied to standard paths
5. See [`powershell/README.md`](powershell/README.md) for details

## Installation Scripts

Available installation scripts in `script/common/`:

### Language Runtimes

- `install_bun.sh` - Bun runtime
- `install_golang.sh` - Go language
- `install_node.sh` - Node.js via NVM
- `install_php.sh` - PHP
- `install_python.sh` - Python with Poetry/UV/Pyenv
- `install_rust.sh` - Rust via rustup

### Development Tools

- `install_gh.sh` - GitHub CLI
- `install_claude.sh` - Claude Code CLI
- `install_yazi.sh` - Yazi file manager + zoxide + bat
- `install_argocd.sh` - ArgoCD CLI
- `install_kubectl.sh` - Kubernetes CLI
- `install_sops.sh` - Mozilla SOPS (secrets management)
- `install_gcloud.sh` - Google Cloud SDK

### Mobile / SDK

- `install_android_sdk.sh` - Android SDK
- `install_flutter.sh` - Flutter SDK
- `install_fvm.sh` - Flutter Version Manager

### TUI Tools

- `install_tui_tools.sh` - Terminal UI tools (batch install)

Included tools:

| Tool | Command | Description |
|------|---------|-------------|
| lazygit | `lazygit` | Git TUI client |
| lazydocker | `lazydocker` | Docker management TUI |
| k9s | `k9s` | Kubernetes management TUI |
| btop | `btop` | System monitor (htop replacement) |
| VHS | `vhs` | Terminal session recorder (GIF/MP4) |
| superfile | `spf` | Modern file manager TUI |
| Glow | `glow` | Terminal markdown renderer |
| slides | `slides` | Terminal presentation tool |
| presenterm | `presenterm` | Markdown-to-slides with code execution |
| lazysql | `lazysql` | Database TUI (MySQL/PostgreSQL/SQLite) |
| posting | `posting` | API client TUI (Postman alternative) |
| harlequin | `harlequin` | SQL IDE TUI (DuckDB/SQLite) |

All scripts support macOS, Ubuntu, and Arch Linux.

## Configuration Priority

- Use `nvim` - Full configuration from nvim/init.lua
- Use `vim` - Configuration from .vimrc
- Both include VSCode-style editing features

## Troubleshooting

**LSP not working in Neovim:**
Run `:Mason` to install language servers manually.

**Tmux navigation not working:**
Ensure vim-tmux-navigator is installed and tmux config is loaded.

**Copilot not working:**
Check GitHub Copilot subscription and run `:Copilot setup` in Neovim.
