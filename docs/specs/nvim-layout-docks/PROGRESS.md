---
spec: nvim-layout-docks
created: 2026-10-02
---

# Progress: Neovim 固定區塊版面

> Spec: `docs/specs/nvim-layout-docks/SPEC.md`

## Phase 1: dock 骨架（R1–R3、R5、R7、R10）

> Status: completed

- 目標：tree、agent、terminal、Trouble 落在左／右／底部三區，尺寸固定。
- Batch 1：edgy 三區、`splitkeep`、`config/layout.lua`；T1、T2、T3、T5、T7、T10 通過。

## Phase 2: 單一插槽與邊界（R4、R6、R8、R9）

> Status: completed

- 目標：agent 與底部面板單一插槽；claudecode diff 留在編輯器；zoom 只作用於編輯器。
- Batch 1：入口處先關其他視窗（只關視窗）；T4、T6、T8、T9 通過；`KEYBINDINGS.md` 已更新。
- Batch 2：R11 無編輯視窗時開 dock（含 `nvim .` 啟動）自動補空編輯視窗；T11 通過，T1、T6、T7 回歸通過。

---

## Completed Phases

<!-- Phase 完成後用 spec-archive.sh phase <slug> 將 phase block 搬到 archive/ -->
<!-- 這裡只留已封存 phase 的簡要記錄 -->
