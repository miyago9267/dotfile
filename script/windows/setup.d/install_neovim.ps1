# 安裝 Neovim + 依賴（對應 setup_neovim.sh）

Write-Host '  安裝 Neovim 與依賴...' -ForegroundColor Yellow

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    # Neovim
    if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
        scoop install neovim
    } else {
        $ver = nvim --version | Select-Object -First 1
        Write-Host "  Neovim 已安裝: $ver" -ForegroundColor Green
    }

    # ripgrep（Telescope 依賴）
    if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
        scoop install ripgrep
    }

    # fd（Telescope file finder 依賴）
    if (-not (Get-Command fd -ErrorAction SilentlyContinue)) {
        scoop install fd
    }

    # gcc（Treesitter parser 編譯；nvim config 會在 Windows 設 CC=gcc）
    if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
        if (scoop list mingw 6>$null | Select-String -Quiet 'mingw') {
            # 已安裝但 PATH 遺失時，reset 會把 bin 加回 User PATH
            scoop reset mingw
        } else {
            scoop install mingw
        }
    }

    # make
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        scoop install make
    }

    # fzf（fzf-lua）、tree-sitter CLI（nvim-treesitter main）、zoxide（archipelago 加資料夾）、
    # win32yank（clipboard provider）
    foreach ($pkg in @(
        @{ Cmd = 'fzf';         Name = 'fzf' }
        @{ Cmd = 'tree-sitter'; Name = 'tree-sitter' }
        @{ Cmd = 'zoxide';      Name = 'zoxide' }
        @{ Cmd = 'win32yank';   Name = 'win32yank' }
    )) {
        if (-not (Get-Command $pkg.Cmd -ErrorAction SilentlyContinue)) {
            scoop install $pkg.Name
        }
    }
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
        winget install Neovim.Neovim --accept-source-agreements --accept-package-agreements
    }
    if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
        winget install BurntSushi.ripgrep.MSVC --accept-source-agreements --accept-package-agreements
    }
    if (-not (Get-Command fd -ErrorAction SilentlyContinue)) {
        winget install sharkdp.fd --accept-source-agreements --accept-package-agreements
    }
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        winget install junegunn.fzf --accept-source-agreements --accept-package-agreements
    }
} else {
    Write-Host '  請先安裝 scoop 或 winget' -ForegroundColor Red
    return
}

# leaf（Markdown 預覽 TUI，leaf.nvim 用；對應 setup_neovim.sh）
if (-not (Get-Command leaf -ErrorAction SilentlyContinue)) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g @rivolink/leaf
    } else {
        Write-Host '  找不到 npm，略過 leaf；Space mp（Markdown 預覽）無法使用' -ForegroundColor Yellow
    }
}

Write-Host '  Neovim 與依賴安裝完成' -ForegroundColor Green
