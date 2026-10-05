---
spec: shared-computer-use
created: 2026-10-04
---

# Progress: 共通 Computer Use MCP 與 desktop-ops 決策層

> Spec: `docs/specs/shared-computer-use/SPEC.md`
> 完整的實作與實機驗收紀錄在 `desktop-ops` repo（private）的 `docs/ACCEPTANCE-LOG.md`。

## Phase 1: S1 共通 driver

> Status: completed（2026-10-04）

- 四個 runtime 經同一支 launcher 註冊 `open-computer-use`；R1 到 R8 通過（見 `TESTS.md`）。
- 與原 plan 的兩處差異記在 SPEC 的 ADR-5 與 ADR-6。

## Phase 2: S2 `desktop-ops` 決策層

> Status: completed（2026-10-05）

- S2a：不叫模型的核心工具、app 與網站黑名單、不搶畫面、不可逆動作的 Touch ID 確認。
- S2b：Jev 決策路徑與外送控制，launcher 預設開啟。
- 追加：以網頁內容的網址屬性支援沒有位址列元素的瀏覽器；Touch ID 人工放行。
- 各階段都經過 `security-reviewer`、fresh `verifier` 與實機驗收。
- 設計在 `desktop-ops` repo 的 `docs/DESIGN.md`；給 agent 的使用規則在
  `config/ai/shared/skills/desktop-ops/SKILL.md`。

## Phase 3: S3 量測

> Status: not-started

- 目標：比較 turn 數、token、延遲，決定原始九個工具是否繼續對 agent 開放。

---

## Completed Phases

<!-- Phase 完成後用 spec-archive.sh phase shared-computer-use 將 phase block 搬到 archive/ -->
