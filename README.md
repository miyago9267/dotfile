# Dotfile

Miyago 的可攜式開發環境設定，支援 macOS、Linux、WSL 與 Windows。

## 咋用

macOS / Linux / WSL：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/miyago9267/dotfile/main/install.sh \
  | bash
```

已有 checkout：

```bash
bash setup.sh
```

Windows：

```powershell
setup.bat
```

## AI agent 設定

日常同步只更新設定與 symlink，不安裝套件：

```bash
git pull --ff-only
bash setup.sh --config-only
```

`--config-only` 會跑 Claude、Codex、Gemini、Pi 的 setup；Grok 與 Astra 要另外跑：

```bash
bash script/common/setup_grok.sh
bash script/common/setup_astra.sh
```

各 runtime 的規則由 setup 合成到 `config/ai/generated/<runtime>/`，來源依序是：

1. `config/ai/AGENTS.md`：共用契約。
2. Personal Model：`~/Project/AI/agent-workspace/personal-model/PROFILE.md`，不在本 repo，可用 `PERSONAL_MODEL_SRC` 指定其他路徑。本機沒有這個檔案時，setup 會沿用已產生檔裡的 Personal Model 區塊，不會清掉。
3. 各 runtime 的 adapter，例如 `config/ai/claude/AGENTS.md`。

改了上面任何一個來源，就重跑對應的 setup，並把 `config/ai/generated/` 一起 commit。

### Claude Code plugins 與主題

`config/ai/claude/settings.json` 記錄啟用的 plugins、marketplaces 與 plugin 選項（含 prismantis 主題）。新機器同步設定後，安裝所有啟用中的 plugins：

```bash
jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' \
  config/ai/claude/settings.json | xargs -n1 claude plugin install
```

`shoal` 與 `baton` 的 marketplace 是本機路徑（`~/.local/share/shoal/claude-marketplace`、`~/Project/Active/baton`），要先在那台機器準備好這兩個 repo，否則這兩個 plugin 會安裝失敗。

## 有啥

`config/` 是設定來源，以下只列實際可攜式的入口和檔案。

- `config/`
  - `ai/`
    - `AGENT-ENTRY.md`、`AGENTS.md`、`runtime-bindings.yaml`
    - `shared/`、`astra/`、`generated/`、`memories/`
    - `claude/`：agents、commands、hooks、MCP、skills、Coralline
    - `codex/`：runtime config、hooks、skills、Coralline
    - `gemini/`、`grok/`、`zed/`
    - `claude-plugin/`、`codex-plugin/`
  - `bash/.bashrc`
  - `zsh/`：`.zshrc`、`.zshenv`、`.p10k.zsh`、`alias.sh`、`.zshrc.d/`
  - `vim/`：`.vimrc`、`base.vim`、`init.vim`
  - `nvim/`：`init.lua`、`lua/config/`、`lua/plugins.lua`、`lazy-lock.json`、`pack/`
  - `git/.gitconfig`
  - `ssh/config`
  - `tmux/`：`base.conf`、`nvim-extension.conf`
  - `ghostty/config`
  - `fastfetch/`：`config.jsonc`、`logo.txt`
  - `vscode/`：`settings.json`、`keybindings.json`、`mcp.json`
  - `opencode/`：runtime、agents、skills、plugins、MCP 和 TUI 設定
  - `opencode-harness/`：harness、agents、package 和 migration 設定
  - `opencode-studio/`：Studio、agents、prompts、toolchain 和 package 設定
  - `windows-terminal/settings.json`
  - `wsl/.wslconfig`
- `script/`
  - `common/`：setup、install、check、test 和 config update scripts
  - `linux/`：Linux 專用 scripts
  - `windows/`：PowerShell profile 和 setup scripts
  - `utils/`：日常 CLI helpers
- `install.sh`、`setup.sh`、`setup.ps1`、`setup.bat`：安裝入口
- `plugins/`：`monika-claude/`、`monika-codex/`、`pilotfish-grok/`
- `template/`、`tools/`、`docs/specs/`：template、獨立工具和 specs
- `INSTALL.md`、`INSTALL_PROMPT.md`、`.env.example`：安裝說明和環境範例
- `secrets/`：受保護資料，不放實際 secret 值
