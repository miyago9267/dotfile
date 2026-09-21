# Pi Runtime Adapter -- Miyago

> 共用身份、溝通、truthfulness、安全與一般 engineering rules 來自
> `config/ai/AGENTS.md`。這份檔案只放 Pi-specific 內容。

## Runtime role

- Pi 是輕量的 terminal coding harness，使用內建 `read`、`write`、`edit`、`bash`
  與 Agent Skills 完成工作。
- 啟用中的 `AGENTS.md` 由 `script/common/setup_pi.sh` 生成，來源順序是 shared
  contract、personal model、這份 adapter。
- 只載入 `config/ai/shared/skills/` 的 shared-core skills。Claude、Codex、Gemini
  的 native workflows、hooks、MCP 與 role routing 不會因為共用 identity 自動生效。
- Pi 使用目前使用者的本機權限，沒有內建 sandbox。project-local `.pi/` resources
  仍須符合 shared contract 的 scope、authority 與 safety boundary。

## Provider and runtime state

- provider、model、subscription、API key 與 OAuth state 是使用者管理的 runtime state。
  用 Pi 的 `/login`、environment variables 或既有 `~/.pi/agent/auth.json` 管理；
  dotfile 不寫入 credential、token、session 或 provider catalog。
- `config/ai/pi/settings.json` 只提供可版本控管的 safe defaults；
  `~/.pi/agent/settings.json` 是 Pi 可更新的 mutable runtime state，setup 只 merge
  defaults，不把它 symlink 回 repo。project `.pi/settings.json` 與 project-local
  extensions/skills 仍由 project owner 管理。
- `~/.pi/agent/sessions/`、`auth.json`、`models-store.json` 與既有 extensions 不納入
  dotfile sync，也不因 setup 重新建立或覆寫。

## Work boundary

- Pi 沒有 Codex/Pilotfish 的 typed role、Claude hooks 或 MCP 的一對一語義；沒有載入的
  capability 不得宣稱已啟用。
- 低風險、local、可逆的 docs/config 工作直接採 `goal -> verify`。external、production、
  credential、privileged、destructive 或不可逆操作仍依 shared contract 取得 authority，
  並保留必要的 safety boundary。
