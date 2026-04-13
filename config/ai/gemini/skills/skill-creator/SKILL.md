---
name: skill-creator
description: "建立新 Gemini skill -- 兩階段流程（草稿 -> 審核），寫入 ~/dotfile/config/ai/gemini/skills/。觸發：使用者說建立 skill、新增 skill、create skill。"
alwaysApply: false
user-invocable: true
---

# skill-creator [name] [description]

建立 Gemini CLI 專屬的新 skill。共用 skill 由 Claude 管理並 symlink 過來；此工具建立的是 Gemini 原生 skill。

## Phase 1：草擬（不寫檔）

1. **查重名**：`ls ~/.gemini/skills/ | grep -i {name}`（含 symlink 的共用 skill）
2. **定 scope**：全域 `~/dotfile/config/ai/gemini/skills/` 或專案 `.gemini/skills/`
3. **定觸發**：alwaysApply: true（規則）/ user-invocable: true（工具）/ alwaysApply: false（情境觸發）
4. **寫 frontmatter + content**（見下方原則）
5. **使用者確認方向** -- 唯一能改內容方向的時間點

## Phase 2：品質審核 + 寫入

6. **自我審核**（結構完整性 + 模擬執行 + 銜接檢查）
7. **處理結果**：通過 -> 寫入 / 不通過 -> 修正後再確認（最多 2 輪）
8. **寫入** `~/dotfile/config/ai/gemini/skills/<name>/SKILL.md`
9. **建立 symlink**：`ln -s ~/dotfile/config/ai/gemini/skills/<name> ~/.gemini/skills/<name>`
10. **驗證**：`ls -la ~/.gemini/skills/<name>/SKILL.md` 確認可存取

## 編寫原則

### Frontmatter

```yaml
---
name: kebab-case              # 必填，routing 用
description: "動詞 + 做什麼 -- 何時/如何"  # 必填，< 120 字
alwaysApply: true/false       # 或 user-invocable: true（二擇一）
---
```

### Description 設計

description 是 Gemini 匹配「使用者問題 -> skill」的依據。

- 放使用者的問題語言（「502」「連不上」「OOM」），不是能力名稱
- 相近 skill 標註邊界，避免觸發衝突
- 不列 CLI 工具名 -- CLI 是實作細節

### Content 必要段落

| 段落 | 必填？ |
|------|--------|
| 目的（一句話） | 必填 |
| 觸發條件 | alwaysApply: false 必填 |
| 流程/規則 | 必填 |
| 與其他 skill 的銜接 | 有相關 skill 時必填 |

### 流程結構

每步三部分：動作 -> 輸出變數 -> OK/FAIL 判定分流

```text
### Step N. 動作 -> 輸出 VAR
{指令}
判定：OK -> 帶 VAR 進 Step N+1 / FAIL -> {處理方式}
```

最後一步必須有出口。

### CLI 處理

假設工具存在，直接跑，失敗才處理。不預先 `which`。

### 自足性

內容自足，不引用外部檔案。無 placeholder。繁體中文 + 英文技術詞。

## 與共用 skill 的關係

- 共用 skill（來自 Claude）：symlink 在 `~/.gemini/skills/`，由 `setup_gemini.sh` 管理
- Gemini 原生 skill：實體檔在 `~/dotfile/config/ai/gemini/skills/`，由此 skill 建立並 symlink
- 若需修改共用 skill，應由 Claude 端修改後同步，不在 Gemini 端覆寫

## 反模式

| 問題 | 正確做法 |
|------|----------|
| description 用能力名稱 | 放使用者問題關鍵字 |
| 步驟沒有判定 | 每步 OK/FAIL + 輸出變數 |
| Phase 1 就寫檔 | 使用者確認後才寫 |
| 重名（含共用 skill） | Step 1 先查 |
| 覆寫共用 skill | 通知使用者走 Claude 端修改 |
