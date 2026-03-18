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

    # gcc（Treesitter parser 編譯）
    if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
        scoop install mingw
    }

    # make
    if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
        scoop install make
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
} else {
    Write-Host '  請先安裝 scoop 或 winget' -ForegroundColor Red
    return
}

Write-Host '  Neovim 與依賴安裝完成' -ForegroundColor Green
