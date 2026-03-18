# Rust 環境（對應 .zshrc.d/rust.zsh）

$cargoEnv = Join-Path $HOME '.cargo' 'env.ps1'
if (Test-Path $cargoEnv) {
    . $cargoEnv
    return
}

# Fallback: 直接加 PATH
Add-PathEntryIfExists (Join-Path $HOME '.cargo' 'bin')
