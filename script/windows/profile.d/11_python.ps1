# Python 環境（對應 .zshrc.d/python.zsh）

# pyenv-win
$pyenvRoot = Join-Path $HOME '.pyenv' 'pyenv-win'
if (Test-Path $pyenvRoot) {
    $env:PYENV = $pyenvRoot
    $env:PYENV_ROOT = $pyenvRoot
    $env:PYENV_HOME = $pyenvRoot
    Add-PathEntryIfExists (Join-Path $pyenvRoot 'bin')
    Add-PathEntryIfExists (Join-Path $pyenvRoot 'shims')
}

# ~/.local/bin（uv, poetry 等工具安裝位置）
Add-PathEntryIfExists (Join-Path $HOME '.local' 'bin')
