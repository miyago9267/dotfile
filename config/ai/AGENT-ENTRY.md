# Canonical AI 設定來源

```yaml
source_root: /Users/miyago/dotfile/config/ai
source_policy: hard
activation: symlinked-or-deployed-to-runtime-locations
workspace_root: /Users/miyago/Project/AI/agent-workspace
workspace_role: canonical-global-rule-base
project_ai_monika: non-entry
```

## 硬邊界

`/Users/miyago/dotfile/config/ai/` 是 Miyago Agent 行為、routing、shared rules、
skills、memories 與 runtime adapters 的唯一 canonical source set。這些檔案會
透過 symlink 或 deployment 接到各 runtime location 後生效；這個 source
directory 本身不是 shared project runtime。

Global Agent experience、task context、system maps 與 handoffs 必須從
`/Users/miyago/Project/AI/agent-workspace/` 讀取。這是 canonical global rule
base，目前第一版只有文件形式。

`/Users/miyago/Project/AI/monika` 明確標記為 `non-entry`。除非 Miyago 的
project-specific task 明確指定該路徑，否則不要讀取、修改、測試它，也不要
從它推論 global Agent behavior。

當任務涉及 global Agent behavior，而 entry set 沒有足夠資訊時，停止並回報
缺少哪些 entry data。不要 fallback 到任何 project checkout。

沒有 fallback workspace。不要因為名稱相似、最近使用或目前 working directory
就拿另一個 project directory 代替。
