# pilotfish-unify 進度

| Phase | 狀態 | 備註 |
|---|---|---|
| P0 保全 opencode | 完成 | Miyago 授權後於 `feat/opencode-role-routing` 本機 commit `39bdff9`（108 檔，含未追蹤目錄展開），未 push；commit 前掃過 secret，只有 env placeholder 與 fixture 假值 |
| P1 骨架 + Claude | 完成（未 commit） | `pilotfish-codex` 的 `feat/multi-host` 工作樹；golden 來源 `pilotfish-claude@1ea9841`；13 檔 byte-identical、`render --check` 綠、15 個新測試綠、全套 481 測試無新增失敗；mutation 檢查確認 frontmatter 由 binding 產生、security→frontier 會被擋 |
| P2 Codex | 完成（未 commit） | 同一工作樹；golden 來源 `pilotfish-codex@61a411b`；`templates/` 12 檔與 plugin policy 副本 byte-identical、tracked 檔零 diff；claude/codex `--check` 皆綠；全套 502 測試 OK；installer dry-run OK；mutation 檢查確認 codex model 由 binding 產生 |
| P3 agy / grok / opencode | 完成（未 commit） | golden：dotfile `b65a243`、`pilotfish-opencode@39bdff9`；三個 host dist byte-identical；5 個 host `--check` 全綠；全套 556 測試 OK；opencode `bun build`/`typecheck` 過、`bun test` 15 pass / 2 skip（live 測試，需 API key）；mutation 檢查 agy、opencode model 皆由 binding 產生；`hosts/opencode/dist/plugin/*.js` 依 R7 留到 P4a 產生 |
| P4a / P4b | 未開始 | repo 名稱已定為 `shoal`，P4a 執行改名 |
| P5 policy 合併 | 未開始 | |

## 審查紀錄

- 2026-09-29 Miyago 核准 spec，並決定 repo 名稱 `shoal`。
- 2026-09-29 plan-verifier 第 1 輪 REVISE（5 blocker），第 2 輪 REVISE（2 blocker），皆已依其 minimum revision 修正；第 2 輪修正未再送審。
