# 安裝 Python 工具鏈（對應 install_python.sh）

Write-Host '  安裝 Python 工具鏈...' -ForegroundColor Yellow

# 安裝 uv（Astral 出品，替代 pip/venv）
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install uv
    } else {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    }
}

# 安裝 Python（透過 uv）
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    uv python install
}

# pyenv-win（可選，若需要多版本管理）
if (-not (Get-Command pyenv -ErrorAction SilentlyContinue)) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install pyenv
        Write-Host '  pyenv-win 已安裝' -ForegroundColor Green
    }
}

Write-Host '  Python 工具鏈安裝完成' -ForegroundColor Green
