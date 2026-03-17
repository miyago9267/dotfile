# Bun 環境（對應 .zshrc.d/bun.zsh）

$bunInstall = Join-Path $HOME '.bun'
if (-not (Test-Path $bunInstall)) { return }

$env:BUN_INSTALL = $bunInstall
Add-PathEntryIfExists (Join-Path $bunInstall 'bin')
