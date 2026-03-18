# GitHub CLI (gh) -- via scoop or winget

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install gh
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
} else {
    Write-Host '  scoop 或 winget 未安裝，無法自動安裝 gh' -ForegroundColor Red
    return
}

Write-Host '  GitHub CLI installed' -ForegroundColor Green
