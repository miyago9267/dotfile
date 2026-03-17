# 安裝 Node.js via fnm（對應 install_node.sh，用 fnm 取代 nvm）

Write-Host '  安裝 fnm + Node.js...' -ForegroundColor Yellow

# 安裝 fnm
if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install fnm
    } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Schniz.fnm --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host '  請先安裝 scoop 或 winget' -ForegroundColor Red
        return
    }

    # 重新載入 PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'User') + [IO.Path]::PathSeparator + $env:PATH
}

# 初始化 fnm（當前 session）
fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# 安裝 Node 22 LTS
fnm install 22
fnm default 22
fnm use 22

# 安裝全域套件
npm install -g npm@latest
npm install -g yarn
npm install -g pnpm

Write-Host '  Node.js 安裝完成' -ForegroundColor Green
$nodeVer = node --version
Write-Host "  Node.js: $nodeVer" -ForegroundColor Cyan
