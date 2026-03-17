# Go 環境（對應 .zshrc.d/go.zsh）

if (-not (Get-Command go -ErrorAction SilentlyContinue)) { return }

# GOPATH 預設
if (-not $env:GOPATH) {
    $env:GOPATH = Join-Path $HOME 'go'
}

# go/bin 加入 PATH
Add-PathEntryIfExists (Join-Path $env:GOPATH 'bin')

# GOROOT/bin（scoop 安裝的 Go 通常已在 PATH，這裡處理手動安裝的情況）
if ($env:GOROOT) {
    Add-PathEntryIfExists (Join-Path $env:GOROOT 'bin')
}
