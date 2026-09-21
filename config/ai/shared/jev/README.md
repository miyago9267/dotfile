# Jev toolbox adapters

這裡只放跨 runtime 的薄 adapter，不放 API key，也不把 Jev 判斷硬編進工作流。

## Capabilities

- `jev-browser`: LLM 提供目標，Jev 選擇頁面元素與動作；遇到不確定或不可逆操作時回傳狀態。
- `Reticle`: 讀取自己開發中的 app 的 DOM、network、console 與 runtime state，回傳 verification evidence。
- `fast-jev-compaction`: 目前只保留為研究項目；尚未接入自動刪除上下文。四個 runtime 都先使用 shadow/dry-run 邊界。

## Runtime mapping

| Runtime | jev-browser | Reticle | compaction |
| --- | --- | --- | --- |
| Claude | MCP | MCP | 既有 hooks；Jev shadow only |
| Codex | MCP | MCP | 既有 hooks；Jev shadow only |
| AGY | MCP | MCP | 既有 hooks；Jev shadow only |
| Pi | CLI/library skill | CLI/library skill | extension 後續接入 |

## Requirements

- Node.js 20.11+；Reticle 官方目前要求此版本。
- AGY 需支援 `agy mcp add/list`；MCP registry 由 `setup_jev.sh` 管理。
- `TYPESAFE_API_KEY` 優先由既有 `sec` 產生的 `~/.env.secrets` 讀取，只注入 MCP
  child process；沒有 cache 時才 fallback 到 `agent-secret`。
- Reticle 另需在每個要驗證的 web/desktop project 執行 `npx @reticlehq/server init`。

## Apply

先看變更：

```sh
bash script/common/setup_jev.sh --dry-run
```

確認後才寫入使用者層的 Claude/Codex/AGY MCP registry：

```sh
bash script/common/setup_jev.sh --apply
```

停用：

```sh
claude mcp remove jev-browser
claude mcp remove reticle
codex mcp remove jev-browser
codex mcp remove reticle
agy mcp remove jev-browser
agy mcp remove reticle
```

AGY 的 `jev-tools` skill 與 permission 由 `setup_gemini.sh` 安裝；
`setup_jev.sh` 不會寫入 key，也不會自動執行 Reticle project init。`sec` 與
KeePassXC 是不同 secret store；要使用 `sec`，先在 `sec edit` 加入
`typesafe.api_key`，再執行 `sec reload`。
