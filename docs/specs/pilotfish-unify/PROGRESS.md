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

- 2026-09-29 已 push：`shoal` main（`7dae849`）推到 `miyago9267/pilotfish-codex`、dotfile main 推到 origin。GitHub repo 改名 `pilotfish-codex` → `shoal` 尚未執行，需 Miyago 確認。
- 2026-09-30 驗證：auto-update 距上次（2026-09-29 12:31）滿 24 小時後的第一個 Claude session 會觸發；確認 `~/.local/state/miyago-agent-stack-updater/update.log` 出現新的 `pilotfish update check passed`，並跑 `check_agent_rule_sync.sh`。
- grok：`shoal/hosts/grok/dist` 尚缺 rules 檔與 AGENT-INSTALL，安裝暫時仍走 `dotfile/plugins/pilotfish-grok`；P4b 前補齊。
- `update_pilotfish` 的 `mktemp -d` 從未清理（P4a 前既有行為），補 trap。
- golden `SOURCE` 的 `dirty: true` 表示匯入自尚未 commit 的 dist；內容已在 `7dae849` commit，verifier 確認不影響回歸測試。

## 審查紀錄（P4a）

- 2026-09-29 plan-verifier 審 P4a 切片：REVISE（marker 位置、golden 更新機制）→ 修正後 READY。
- 2026-09-29 fresh verifier：CONFIRMED（宣稱 1–7 皆有證據）；advisory：已安裝 SKILL.md 的 marker 未 commit 會擋 revert（已隨本進度一併 commit）、暫存目錄未清理（列入待辦）。

## shoal v1.0.0 發布（2026-09-30）

- 新 public repo `miyago9267/shoal`，繼承完整 history、不繼承舊 tag；Release `v1.0.0`（Latest）指向 `e4e1808`，三平台 Python tests 與 Markdown lint 綠。
- 版本分層：shoal 產品版 `VERSION` = 1.0.0；codex host 版 `hosts/codex/VERSION` = 1.8.1，輸出不變。
- 舊 repo `miyago9267/pilotfish-codex`：main `cec6659` README 加遷移說明；舊 tag 全數留在遠端：codex 的 tag 在 `pilotfish-codex`（本機唯一未推的 `v1.8.0` 已補推），v1.1.x、v1.3.x 等 12 個屬於上游 `Nanako0129/pilotfish`；本機 remote 改名 `pilotfish-codex`、`origin` 指向 shoal，舊 remote 設 `--no-tags`。
- 發布過程的兩個失誤與處理：
  1. 本機既有 codex 時期 `v1.0.0` tag 撞名，指令鏈未擋住，舊 tag 被推到新 repo；數分鐘內刪除，改為本機移除全部舊 tag 後重建。
  2. installer 新增的中文註解讓 Windows 測試（未指定編碼讀檔）失敗；註解改英文於 `e4e1808`，經 Miyago 同意把尚未發 Release 的 `v1.0.0` tag 從 `b947d47` 移到 `e4e1808`。
- shoal 工作樹另有 Miyago 的未 commit WIP（codex root 改 `gpt-6.1-sol`），依決定不納入 v1.0.0。
- 2026-09-30 fresh verifier：CONFIRMED（repo/tag、Release Latest、三平台 CI、版本分層、codeload 可取得、舊 repo 遷移說明、WIP 未入 commit、連結、dotfile auto-update 與 sync check）。
