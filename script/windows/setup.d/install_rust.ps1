# 安裝 Rust via rustup（對應 install_rust.sh）

if (Get-Command rustc -ErrorAction SilentlyContinue) {
    $ver = rustc --version
    Write-Host "  Rust 已安裝: $ver" -ForegroundColor Green
    return
}

Write-Host '  安裝 Rust...' -ForegroundColor Yellow

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install rustup
    rustup-init -y
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install Rustlang.Rustup --accept-source-agreements --accept-package-agreements
} else {
    # 直接下載安裝
    $rustupInit = Join-Path $env:TEMP 'rustup-init.exe'
    Invoke-WebRequest -Uri 'https://win.rustup.rs/x86_64' -OutFile $rustupInit
    & $rustupInit -y
    Remove-Item $rustupInit -ErrorAction SilentlyContinue
}

Write-Host '  Rust 安裝完成，重啟終端後生效' -ForegroundColor Green
