# kubectl -- via scoop or winget

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install kubectl
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Kubernetes.kubectl -e --accept-source-agreements --accept-package-agreements
} else {
    Write-Host '  scoop 或 winget 未安裝，無法自動安裝 kubectl' -ForegroundColor Red
    return
}

Write-Host '  kubectl installed' -ForegroundColor Green
