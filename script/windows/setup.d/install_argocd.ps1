# Argo CD CLI -- via scoop

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install argocd
} else {
    Write-Host '  scoop 未安裝，無法自動安裝 argocd' -ForegroundColor Red
    Write-Host '  手動安裝: https://argo-cd.readthedocs.io/en/stable/cli_installation/' -ForegroundColor Yellow
    return
}

Write-Host '  Argo CD CLI installed' -ForegroundColor Green
