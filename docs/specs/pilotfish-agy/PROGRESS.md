# pilotfish-agy Progress

## Phase 1: 格式探測 -- 完成（2026-09-23）

結果記在 SPEC.md「Phase 1 探測結果」。

## Phase 2: 樣板與安裝 -- 完成（2026-09-23）

- `plugins/pilotfish-agy/`：7 份 agent.md、常駐 rule、`pilotfish-orchestration` skill、README。
- `script/common/setup_gemini.sh`：agents 與 skill 只裝給 agy（`~/.gemini/config/`），
  rule 併入 `GEMINI.md`。
- 靜態與安裝測試 `tests/test_templates.py`：先 Red（18 項失敗），後 Green（6/6）。
- 依 Miyago 指示，安全邊界採基礎、成比例的做法：避免只看單一邊界（tunnel
  vision），不為了安全而收窄執行角色的能力。

## Phase 3: 端對端驗證 -- 完成（2026-09-23）

- `tests/e2e.sh` ALL PASS：R1 七個角色可列出；R2 scout -> `gemini-3.8-flash`、
  plan-verifier -> `gemini-3.1-pro`；R3 scout 寫不了檔；R4 verifier 可跑指令；
  skill 可見。
- 除錯紀錄：tier 偵測需同時讀 `.db-wal`、排除含多角色標記的主 session DB（有其他
  agy session 並行時會汙染），且 `pipefail` 下不可用 `grep -q`（SIGPIPE）。
- `view_code_item`、`command_status`、`read_terminal` 於 15:35 被並行的 agy session
  從 `tools` 移除；移除前 R4 失敗、移除後通過，推測未知工具名會讓 agent 失效
  （未單獨重現）。
- fresh `verifier`：CONFIRMED。P3 建議（常駐 gate 未限定大型任務）已修正，
  並以 agy 實測小改動會直接執行、不觸發 Plan。
