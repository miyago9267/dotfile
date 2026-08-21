# Dotfile

Miyago 的個人開發環境 playbook。除了保存 dotfiles，也統一管理
macOS / Linux 工具安裝、AI CLI 設定、runtime 與常用開發工具。

這個 repo 很雜，基本上就是我平常會用到的設定和安裝腳本，想到什麼就慢慢補進來。

## 怎麼用

先把 repo clone 下來，然後跑 setup：

```bash
git clone https://github.com/miyago9267/dotfile.git
cd dotfile
bash setup.sh
```

想全部跑完可以用：

```bash
bash setup.sh --all
```

安裝失敗的 component 會把輸出和 exit code 記到根目錄的 `error.log`，方便之後回頭看。

## 裡面大概有什麼

- macOS、Ubuntu/Debian、Arch Linux 的安裝腳本
- Windows PowerShell 設定
- Vim、Neovim、Tmux 和 shell 設定
- Claude Code、Codex、Gemini CLI 的設定與 skills
- Node、Python、Go、Rust、Bun 等 runtime
- Kubernetes、cloud CLI、Android、Flutter 和一些平常會用的 TUI 工具

## Agent Workflow Factory 的邊界

這個 repo 只保存 runtime 設定與 adapter：例如 generated instruction、skills、hooks、MCP 設定、CLI bootstrap 與 symlink setup。它不保存 Context Harness 本體、task/experience 資料、benchmark 結果或 Factory 的安裝入口。

那些內容由獨立的 `Agent Workflow Factory` repository 管理。Factory 安裝時透過 `MIYAGO_AGENT_WORKSPACE_ROOT` 與 `MIYAGO_DOTFILE_ROOT` 把這個設定來源接上；因此換 Factory 版本不會複製或接管 dotfile，換 runtime 也不需要把經驗資料塞進設定 repo。

日常接入 Factory 的入口是：

```bash
agent-workflow runtime sync --all
agent-workflow runtime doctor
```

runtime-specific 的 hook 與設定仍由本 repo 負責；Factory 只使用它們提供的 bootstrap contract，不把 runtime 實作混進核心 Harness。

## AI skills

Codex 的 native skills 放在 `config/ai/codex/skills/`，Claude 共用的 skills 放在
`config/ai/claude/skills/`。另外有一個獨立的 [`build-install`](https://github.com/miyago9267/build-install) skill，專門幫其他專案產生兩種安裝入口：

- 給 agent 讀的 `INSTALL.md` 和安裝 prompt
- 給人直接 `curl | bash` 使用的 `install.sh`

## 目錄看不懂也沒關係

大概可以先看這幾個地方：

```text
config/ai/    AI CLI 設定和 skills
script/       各種安裝腳本
powershell/   Windows 設定
nvim/         Neovim 設定
tmux/         Tmux 設定
setup.sh      macOS/Linux 的入口
```

這份設定主要是給我自己用的，直接拿去別台機器跑之前，建議先看一下腳本會改哪些檔案。
