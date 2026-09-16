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
