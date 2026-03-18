# pnpm 環境（對應 .zshrc.d/pnpm.zsh）

# Windows 上 pnpm 預設位置
$pnpmCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'pnpm')
    (Join-Path $HOME '.local' 'share' 'pnpm')
)

foreach ($dir in $pnpmCandidates) {
    if (Test-Path $dir) {
        $env:PNPM_HOME = $dir
        Add-PathEntryIfExists $dir
        break
    }
}
