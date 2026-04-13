---
name: search-discipline
description: 搜索效率紀律 -- 限制 codebase_investigator 的濫用，優先使用 grep_search、glob 和 read_file 進行外科手術式搜索。永遠生效。
---

# search-discipline -- 搜索效率紀律

控管搜索行為的 token 消耗與回合數 (turns)。`codebase_investigator` 一次呼叫可能啟動多輪子代理解析，消耗大量 context。大多數搜尋任務應優先使用精確工具。

## 搜索工具選擇順序

```text
搜索需求
  ├─ 知道檔名或路徑 Pattern → glob (1 call)
  ├─ 知道關鍵字或符號 → grep_search (1 call) → read_file (N calls)
  ├─ 探索目錄結構 → list_directory
  ├─ 需要對大量檔案進行批次處理 → generalist (1 call)
  └─ 以上都不行，涉及複雜架構分析或跨檔案依賴 → codebase_investigator (最後手段)
```

## 規則

1. **grep_search 優先**：找關鍵字、函數、class 名、import 路徑。利用 `context`、`before`、`after` 參數一次取得足夠資訊，減少 `read_file` 的回合。
2. **glob 優先**：找檔案 pattern（`**/*.ts`、`src/**/index.*`）。
3. **read_file 外科手術**：已知路徑時，優先使用 `start_line` 和 `end_line` 讀取特定片段，避免載入完整大檔案。
4. **codebase_investigator 是最後手段**：只在需要跨檔案深入理解、涉及複雜架構重構、或追查根因 (Root Cause) 時使用。
5. **generalist 適用批次任務**：當需要在超過 3 個檔案中執行重複的 read/search/edit 時，委派給 `generalist` 處理以壓縮主對話 context。
6. **限制搜索範圍**：無論使用哪種工具，都要指定 `include_pattern` 或 `dir_path`，不要搜索無關目錄（如 `node_modules`、`.git`）。

## 好的做法範例

### 壞的做法（依賴 codebase_investigator）

```text
問：找出所有跟 ask-tty 相關的檔案並分析其連線邏輯。
codebase_investigator(objective="...")
→ 啟動子代理解析 10+ 輪，消耗 20k+ tokens
```

### 好的做法（組合精確工具）

```text
1. grep_search(pattern="ask-tty", total_max_matches=50)
2. 根據結果 glob(pattern="**/ask-tty/**")
3. read_file(file_path="...", start_line=..., end_line=...)
= 3-5 回合，消耗 < 2k tokens
```

## 反模式與正確做法

| 行為 | 缺點 | 正確做法 |
|------|------|----------|
| 用 investigator 找已知路徑 | 浪費 turns | 直接 glob 或 read_file |
| 讀取完整大型日誌檔案 | context 爆炸 | grep_search 找關鍵字或 read_file 特定區間 |
| 不帶 include_pattern 的 grep | 噪聲太多 | 指定檔案類型 (e.g., `*.ts`) |
| 反覆切換目錄 list_directory | 消耗回合 | 直接用 glob `**/*.ext` 一次找齊 |

## 成本意識

- **grep_search / glob**: 極低消耗，單一回合。
- **read_file**: 中等消耗（取決於讀取範圍）。
- **generalist / codebase_investigator**: 昂貴！這會開啟全新的執行環境並在主歷史中產生摘要，應謹慎使用。
- **一輪浪費的轉向 = 潛在的 context 遺忘起點。**
