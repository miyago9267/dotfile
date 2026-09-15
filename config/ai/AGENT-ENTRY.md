# Canonical AI 設定來源

```yaml
source_root: /Users/miyago/dotfile/config/ai
source_policy: hard
activation: symlinked-or-deployed-to-runtime-locations
workspace_root: /Users/miyago/Project/AI/agent-workspace
workspace_role: canonical-global-rule-base
project_ai_monika: non-entry
identity:
  canonical_name: Astra
  legacy_aliases: [Monika, monika, monika-large, studio-monika]
  source: /Users/miyago/dotfile/config/ai/AGENTS.md
```

## 硬邊界

`/Users/miyago/dotfile/config/ai/` 是 Miyago Agent 行為、routing、
shared rules、skills、memories 與 runtime adapters 的唯一 canonical
source set。
設定會透過 symlink 或 deployment 接到各 runtime location 後生效。
這個 source directory 本身不是 shared project runtime。

Global Agent experience、task context、system maps 與 handoffs 必須從
`/Users/miyago/Project/AI/agent-workspace/` 讀取。
這是 canonical global rule base，目前第一版只有文件形式。

`/Users/miyago/Project/AI/monika` 明確標記為 `non-entry`。
除非 Miyago 的 project-specific task 明確指定該路徑，
否則不要讀取、修改、測試它，也不要從它推論 global Agent
behavior。

當任務涉及 global Agent behavior，而 entry set 沒有足夠資訊時，
停止並回報缺少哪些 entry data。不要 fallback 到任何 project
checkout。

沒有 fallback workspace。不要因為名稱相似、最近使用或目前
working directory 就拿另一個 project directory 代替。

## Identity routing

`config/ai/AGENTS.md` 的 Astra identity 是所有 runtime 的唯一 persona
source。舊 runtime、plugin 與 OpenCode agent ID 保留原名以維持
相容性。遇到 `Monika` 或 `monika-*` 時，視為 Astra alias，不再
讀取第二套 persona。
只有明確啟用 Astra profile 時，才載入
`config/ai/astra/AGENTS.md` 的 compact overlay。
