# 安裝 Nerd Fonts（對應 setup_fonts.sh）

Write-Host '  安裝 Nerd Fonts...' -ForegroundColor Yellow

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    # 確保 nerd-fonts bucket 已加入
    $buckets = scoop bucket list 2>$null
    if ($buckets -notmatch 'nerd-fonts') {
        scoop bucket add nerd-fonts
    }

    # 安裝 MesloLGS NF（p10k / oh-my-posh 推薦字型）
    scoop install nerd-fonts/Meslo-NF
    scoop install nerd-fonts/FiraCode-NF
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    # 用 winget 安裝
    winget install --id=Nerd.Fonts.Meslo --accept-source-agreements --accept-package-agreements 2>$null
} else {
    Write-Host '  請先安裝 scoop 或 winget' -ForegroundColor Red
    return
}

Write-Host '  Nerd Fonts 安裝完成' -ForegroundColor Green
Write-Host '  請在 Windows Terminal 設定中將字型設為 "MesloLGS NF" 或 "FiraCode Nerd Font"' -ForegroundColor Cyan
