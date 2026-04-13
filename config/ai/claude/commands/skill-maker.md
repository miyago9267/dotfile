---
name: skill-maker
description: "建立新 skill -- 兩階段流程（草稿 -> 審核），確保 frontmatter 完整、流程有進出、skill 間不斷鏈。"
---

# /skill-maker [name] [description]

## Phase 1：草擬（不寫檔）

1. **查重名**：`ls ~/dotfile/config/ai/claude/skills/ | grep -i {name}` + plugin 目錄
2. **定 scope**：全域 `~/dotfile/config/ai/claude/skills/` 或專案 `.claude/skills/`
3. **定觸發**：alwaysApply: true（規則）/ user-invocable: true（工具）/ alwaysApply: false（情境觸發）
4. **寫 frontmatter + content**（見下方原則）
5. **使用者確認方向** -- 唯一能改內容方向的時間點

## Phase 2：品質審核 + 寫入

6. **Reviewer agent 審核**（結構 + 模擬執行 + 銜接測試，見下方）
7. **處理結果**：APPROVE -> 寫入 / REVISE -> 只修品質不改方向（最多 2 輪）
8. **寫入** `~/dotfile/config/ai/claude/skills/<name>/SKILL.md`
9. **更新相關 skill 的銜接段落**（雙向同步）

## 編寫原則

### Frontmatter

```yaml
---
name: kebab-case              # 必填，routing 用
description: "動詞 + 做什麼 -- 何時/如何"  # 必填，< 120 字
alwaysApply: true/false       # 或 user-invocable: true（二擇一）
---
```

### Description 關鍵字設計

description 是 Claude 匹配「使用者問題 -> skill」的唯一依據（SKILL.md 全文觸發後才載入）。

- 放使用者的問題語言（「502」「連不上」「OOM」），不是能力名稱（「健康度檢查」）
- 相近 skill 必須標註邊界（「日常追蹤由 auto-spec 處理；手動啟動用 /sdd」）
- 不需要列 CLI 工具名 -- CLI 是實作細節

### Content 必要段落

| 段落 | 必填？ |
|------|--------|
| 目的（一句話） | 必填 |
| 觸發條件 | alwaysApply: false 必填 |
| 流程/規則 | 必填 |
| 與其他 skill 的銜接 | 有相關 skill 時必填 |
| 規則 | 必填 |

### 流程結構要求

每步三部分：動作 -> 輸出變數 -> OK/FAIL 判定分流

```text
### Step N. 動作 -> 輸出 VAR
{指令}
判定：OK -> 帶 VAR 進 Step N+1 / FAIL -> 分流到 {skill}，帶入 {已確認變數}
```

最後一步必須有出口。銜接段落標明：從哪來（跳到哪步 + 已確定變數）、到哪去。

### CLI 處理

假設工具存在，直接跑，失敗才處理。不預先 `which`。

### 自足性

內容自足，不引用外部檔案。無 placeholder。繁體中文 + 英文技術詞。

## Reviewer Agent 審核

啟動 general-purpose agent，傳入草稿全文，做三項審核：

1. **結構檢查**（13 項 PASS/FAIL）：frontmatter 完整、description 有問題關鍵字、流程有輸出變數和分流、銜接段落雙向對得上
2. **模擬執行**：場景 A 正常路徑 / 場景 B 中途 FAIL -- 能不能走完不斷鏈
3. **銜接測試**：讀取相關 skill 的 SKILL.md，確認變數名和步驟號對得上

輸出：APPROVE / REVISE（附具體修改建議）

## 從 /learn 升級

confidence >= 0.9 的 pattern -> 提取 trigger + action -> 走 Phase 1 Step 3-5 -> Phase 2

## 反模式

| 問題 | 正確做法 |
|------|----------|
| description 用能力名稱 | 放使用者問題關鍵字 |
| 步驟沒有判定 | 每步 OK/FAIL + 輸出變數 |
| 分流不帶變數 | 列出帶入的已確認變數 |
| 預先檢查 CLI 安裝 | 直接跑，失敗才處理 |
| 引用外部檔案 | 內容自足 |
| Phase 1 就寫檔 | 使用者確認後才寫 |
| 重名 | Step 1 先查 |
