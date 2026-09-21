# Miyago Dotfile Agent Install Playbook

這份文件給 AI agent 執行。先讀完整文件，再依目前作業系統選擇路徑。

## Scope

- Repository: `/Users/miyago/dotfile`，或目前 checkout 的 repo root。
- macOS / Linux / WSL：使用 `setup.sh` 與 `script/common/`。
- Windows：使用 `setup.ps1` 與 `script/windows/setup.d/`。
- Config sync 與 environment install 必須分開處理。
- Android SDK、Flutter、FVM 是 optional；沒有明確需求時禁止安裝。

## Confirmation boundary

在執行前先報告將要做的模式與項目，並在下列情況停下等待使用者確認：

- 需要 `sudo`、Homebrew、apt、pacman、Scoop 或 winget。
- 修改 `~/.zshrc`、`~/.zshenv`、PowerShell profile 或其他 global shell settings。
- 安裝 Node、Python、Go、Rust、Bun、Cloud CLI 或其他非 config 工具。
- 使用 `--all`、`--everything`，或任何會安裝多個未指定工具的命令。
- 使用者工作樹有未提交的 tracked changes，且操作可能覆蓋其檔案。

不要求、讀取或寫入 secrets。不要把 token、API key、KeePassXC 密碼或 `.env`
內容輸出到對話、log 或 commit。

## Preflight

在 repository root 執行：

```bash
git status --short --branch
git remote -v
uname -s 2>/dev/null || true
```

閱讀實際入口與 help：

```bash
sed -n '1,120p' setup.sh
bash setup.sh --help
```

Windows 先確認：

```powershell
$PSVersionTable.PSVersion
Get-Command pwsh, fzf, scoop, winget -ErrorAction SilentlyContinue
```

不要因為 README、歷史文件或其他 checkout 的內容推測目前入口；以目前檔案與
`--help` 輸出為準。

## Remote bootstrap

macOS、Linux 與 WSL 可以不先建立 git checkout，直接從 GitHub 下載 source
archive：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/miyago9267/dotfile/main/install.sh \
  | bash -s -- --config-only
```

執行前先讀取實際 installer：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/miyago9267/dotfile/main/install.sh \
  | sed -n '1,260p'
```

installer 預設把 source 放到 `~/dotfile`，已有的同名目錄會先移到帶時間戳的
`.backup` 目錄。它使用 HTTPS archive，不需要 `git clone`，也不會自行使用
`sudo`。第一次接入建議用 `--config-only`；環境工具要逐項確認後再安裝。

要固定 branch、tag 或 commit，installer URL 和 `--ref` 要使用同一個值：

```bash
ref=main
curl -fsSL \
  "https://raw.githubusercontent.com/miyago9267/dotfile/$ref/install.sh" \
  | bash -s -- --ref "$ref" --config-only
```

可用 `--dry-run` 先確認 ref、目標目錄和 setup mode；Windows 請下載 repository
後使用 `setup.bat`，不走這個 Unix remote bootstrap。

## Recommended path: config sync

日常更新 remote 設定時，只做 config sync：

```bash
git pull --ff-only
bash setup.sh --config-only
```

Windows：

```powershell
git pull --ff-only
pwsh ./setup.ps1 -ConfigOnly
```

這條路徑會更新 repository-managed config、generated runtime entries 與 symlink。
它不應安裝套件、升級 CLI、建立 secrets placeholder 或安裝 Android / Flutter。

執行前檢查目前 symlink 及來源；若目標是一般檔案或目錄，先停下並報告，因為
macOS/Linux 的 `setup_dotfiles.sh` 可能以 `ln -sf` 取代目標。

## Environment install

環境安裝只執行使用者明確指定的項目。先列出候選腳本：

```bash
printf '%s\n' script/common/dependencis.sh script/common/setup_zsh.sh \
  script/common/setup_neovim.sh script/common/setup_tmux.sh \
  script/common/install_*.sh
```

互動式人類入口：

```bash
bash setup.sh --environment
```

Agent 不應依賴互動 TUI 選擇。應直接執行已確認的個別腳本，例如：

```bash
bash script/common/dependencis.sh
bash script/common/setup_zsh.sh
```

每個腳本執行前先閱讀其內容，確認平台、權限、下載來源與會修改的路徑。不要
把 `--all` 當成個別環境安裝的替代方案。

Windows 的人類入口：

```powershell
pwsh ./setup.ps1 -Environment
```

Agent 應改為執行已確認的 `script/windows/setup.d/*.ps1` 個別腳本，不要以
`-Everything` 安裝整包工具。

## Optional mobile tools

只有使用者明確要求 Android / Flutter 工作環境時才可執行：

```bash
bash setup.sh --everything
```

執行前必須列出將額外安裝的 Flutter、FVM、Android SDK，並取得確認。Windows
同理使用 `-Everything` 前必須確認。

## Verification

Config sync 後至少檢查：

```bash
find config/zsh -type f -name '*.zsh*' -print0 | xargs -0 zsh -n
test -L "$HOME/.zshrc" && readlink "$HOME/.zshrc"
test -L "$HOME/.zshenv" && readlink "$HOME/.zshenv"
git diff --check
git status --short --branch
```

Environment install 後只驗證已選項目，例如：

```bash
command -v zsh || true
command -v nvim || true
command -v tmux || true
```

不要宣稱 WSL、Windows 或其他未實際執行的作業系統已驗證。PowerShell 若本機
沒有 `pwsh`，明確回報未驗證。

## Failure and rollback

- 任一腳本失敗就停止後續未確認項目，保留 exit code 與精簡錯誤輸出。
- `setup.sh` 會把安裝失敗輸出附加到 repo root 的 `error.log`；不要把 secrets
  貼入回報。
- 不要刪除 backup 檔、使用者設定或未追蹤檔案。
- 不要執行 `git reset --hard`、`git clean`、force push 或廣泛 `rm`。
- 若 symlink 目標被替換，先報告實際目標與來源；rollback 必須由使用者決定，
  不要自行猜測原始檔案位置。

## Agent report

完成後回報：

1. OS 與實際執行模式。
2. 執行的確切命令與項目。
3. 成功的 verification 結果。
4. 未驗證的平台、未完成項目與需要使用者決定的權限操作。
5. 是否產生或保留 backup、error log 或未提交變更。
