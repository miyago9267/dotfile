# Node.js 環境（fnm，對應 .zshrc.d/nvm.zsh）

if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) { return }

fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
