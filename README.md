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
├── nvim
│   ├── coc-config.vim
│   ├── init.lua
│   ├── lazy-lock.json
│   └── pack/
├── script
│   ├── installations
│   └── utils
├── template
│   └── template.cpp
├── tmux
│   ├── base.conf
│   └── nvim-extension.conf
├── alias.sh
├── init.vim
├── .vimrc
├── setup.sh
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

## How it work

1. Detect operating system (macOS/Ubuntu/Arch)
2. Install system packages via package manager
3. Download and setup plugins
4. Configure Vim, Neovim, and Tmux
5. Link configuration files to home directory
6. Install language runtimes (optional)

## Installation Scripts

Available installation scripts in `script/installations/`:

- `install_android_sdk.sh` - Android SDK
- `install_bun.sh` - Bun runtime
- `install_flutter.sh` - Flutter SDK
- `install_fvm.sh` - Flutter Version Manager
- `install_gcloud.sh` - Google Cloud SDK
- `install_golang.sh` - Go language
- `install_node.sh` - Node.js via NVM
- `install_php.sh` - PHP
- `install_pnpm.sh` - pnpm package manager
- `install_python.sh` - Python with Poetry/UV/Pyenv
- `install_rust.sh` - Rust via rustup

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
