# pilotfish-unify 進度

| Phase | 狀態 | 備註 |
|---|---|---|
| P0 保全 opencode | 完成 | Miyago 授權後於 `feat/opencode-role-routing` 本機 commit `39bdff9`（108 檔，含未追蹤目錄展開），未 push；commit 前掃過 secret，只有 env placeholder 與 fixture 假值 |
| P1 骨架 + Claude | 完成（未 commit） | `pilotfish-codex` 的 `feat/multi-host` 工作樹；golden 來源 `pilotfish-claude@1ea9841`；13 檔 byte-identical、`render --check` 綠、15 個新測試綠、全套 481 測試無新增失敗；mutation 檢查確認 frontmatter 由 binding 產生、security→frontier 會被擋 |
| P2 Codex | 完成（未 commit） | 同一工作樹；golden 來源 `pilotfish-codex@61a411b`；`templates/` 12 檔與 plugin policy 副本 byte-identical、tracked 檔零 diff；claude/codex `--check` 皆綠；全套 502 測試 OK；installer dry-run OK；mutation 檢查確認 codex model 由 binding 產生 |
| P3 agy / grok / opencode | 完成（未 commit） | golden：dotfile `b65a243`、`pilotfish-opencode@39bdff9`；三個 host dist byte-identical；5 個 host `--check` 全綠；全套 556 測試 OK；opencode `bun build`/`typecheck` 過、`bun test` 15 pass / 2 skip（live 測試，需 API key）；mutation 檢查 agy、opencode model 皆由 binding 產生；`hosts/opencode/dist/plugin/*.js` 依 R7 留到 P4a 產生 |
| P4a 切換 | 完成 | repo 改名 `shoal`（舊路徑 symlink 相容）；`shoal` main `7dae849`（本機，未 push）；dotfile 切換 `a6ca86e`；S7 實跑 auto-update / opencode install / setup_gemini，安裝結果與切換前相同（僅多 marker）；fresh verifier CONFIRMED |
| P4b 封存 | 未開始 | 前置：P4a 後 auto-update 連續 7 天成功，最早 2026-10-06 |
| P5 policy 合併 | 未開始 | |

## 審查紀錄

- 2026-09-29 Miyago 核准 spec，並決定 repo 名稱 `shoal`。
- 2026-09-29 plan-verifier 第 1 輪 REVISE（5 blocker），第 2 輪 REVISE（2 blocker），皆已依其 minimum revision 修正；第 2 輪修正未再送審。

## P4a 後待辦

- GitHub 改名 `pilotfish-codex` → `shoal` 與 push：external mutation，需 Miyago 確認。
- grok：`shoal/hosts/grok/dist` 尚缺 rules 檔與 AGENT-INSTALL，安裝暫時仍走 `dotfile/plugins/pilotfish-grok`；P4b 前補齊。
- `update_pilotfish` 的 `mktemp -d` 從未清理（P4a 前既有行為），補 trap。
- golden `SOURCE` 的 `dirty: true` 表示匯入自尚未 commit 的 dist；內容已在 `7dae849` commit，verifier 確認不影響回歸測試。

## 審查紀錄（P4a）

- 2026-09-29 plan-verifier 審 P4a 切片：REVISE（marker 位置、golden 更新機制）→ 修正後 READY。
- 2026-09-29 fresh verifier：CONFIRMED（宣稱 1–7 皆有證據）；advisory：已安裝 SKILL.md 的 marker 未 commit 會擋 revert（已隨本進度一併 commit）、暫存目錄未清理（列入待辦）。
