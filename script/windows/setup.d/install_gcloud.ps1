# Google Cloud SDK -- via scoop or official installer

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install gcloud
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Google.CloudSDK -e --accept-source-agreements --accept-package-agreements
} else {
    Write-Host '  scoop 或 winget 未安裝，無法自動安裝 gcloud' -ForegroundColor Red
    Write-Host '  手動安裝: https://cloud.google.com/sdk/docs/install' -ForegroundColor Yellow
    return
}

Write-Host '  Google Cloud SDK installed' -ForegroundColor Green
