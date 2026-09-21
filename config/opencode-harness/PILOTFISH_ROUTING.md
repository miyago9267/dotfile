<!-- markdownlint-disable MD013 -->

# Pilotfish OpenCode Local Routing

這是本機 opencode-harness 的第一版 provider／role 分配。daily
opencode 不載入這份 plugin，也不共用這份 role model binding。

## 啟用方式

所有 level 共用同一個 opencode-harness／och 入口；level 只影響 role
到 model 的內部分配，不建立分級指令或分開的啟動流程。harness config
會載入本機安裝的
pilotfish-opencode plugin；目前安裝檔由 sibling project 的 source build
產生，位置是 config/opencode-harness/plugins/pilotfish-opencode.js。

需要重建 local plugin 時，執行
config/opencode-harness/install-pilotfish.sh；可用
PILOTFISH_OPENCODE_SOURCE 指定 sibling project 位置。

目前工作目錄若有 .opencode/pilotfish/catalog.json，plugin 會驗證
provider、model、capability 與 authentication state；可選的
.opencode/pilotfish/routing.json 會提供 candidate order 和 fallback。

## 初步分層

| 層級 | 使用時機 | 本機 model |
| --- | --- | --- |
| Cheap labor | 唯讀探索、知識庫索引、瀏覽研究 | deepseek/deepseek-v4-flash、google/gemini-2.5-flash |
| Senior labor | 實作、機械執行、一般 diff review | openai/gpt-5.6-luna、xai/grok-4.6 |
| High-level reasoning | plan challenge、security、verification | openai/gpt-5.6-sol（暫時 fallback） |
| Default primary | daily／harness 主 session | openai/gpt-5.6-luna（`reasoningEffort: max`） |

## Role assignment

| OpenCode agent | Role tier | Assigned model | Boundary |
| --- | --- | --- | --- |
| repo-explorer | Cheap labor | deepseek/deepseek-v4-flash | 唯讀 repository search |
| vault-librarian | Cheap labor | deepseek/deepseek-v4-flash | 唯讀 knowledge-base search |
| scout | Cheap labor | google/gemini-2.5-flash | 唯讀 bounded reconnaissance |
| browser-crawler | Cheap labor | google/gemini-2.5-flash | bounded web／browser research |
| mech-executor | Senior labor | openai/gpt-5.6-luna | 已明確規格的 mechanical edit |
| executor | Senior labor | openai/gpt-5.6-luna | 有局部判斷的 bounded implementation |
| implementation-worker | Senior labor | openai/gpt-5.6-luna | 指定檔案的 implementation |
| reviewer | Senior labor | xai/grok-4.6 | 獨立 diff／risk review |
| monika-large | Default primary | openai/gpt-5.6-luna（`reasoningEffort: max`） | 主 session、整合與 final judgment |
| plan-verifier | High-level reasoning | openai/gpt-5.6-sol | READY／REVISE plan challenge |
| verifier | High-level reasoning | openai/gpt-5.6-sol | CONFIRMED／REFUTED acceptance check |
| security-reviewer | High-level reasoning | openai/gpt-5.6-sol | security evidence review |
| security-executor | High-level reasoning | openai/gpt-5.6-sol | approved security-sensitive edit |

## Model evidence and limits

- deepseek/deepseek-v4-flash、google/gemini-2.5-flash、
  openai/gpt-5.6-luna、openai/gpt-5.6-sol 都已出現在本機 OpenCode
  model catalog；目前 routing catalog 也宣告了 tools／streaming，reasoning
  只給有 catalog evidence 的 model。
- xai/grok-4.6 出現在 xai 的 OpenCode model catalog，且本機有 xAI
  auth entry；本次只驗證 config／catalog，尚未用它跑 live request。
- fable、opus5、gpt 6 astra 目前沒有本機可確認的 provider/model
  identity。它們只保留為 high-level preferred candidates，沒有寫入 active
  route；等 customer provider 宣告後再加入該客戶自己的 catalog。
- provider credential 仍由 OpenCode auth／environment 管理；本檔與
  .opencode/pilotfish/ 不保存 secret value。

## Safety boundary

Cheap labor 只承擔 discovery、indexing 與 bounded research。寫入、security
與 completed-work verification 使用 senior 或 high-level tier；route
fallback 不會放寬 OpenCode native permission。
