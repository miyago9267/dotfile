# Miyago 專案索引 Routing

這份 skill 是專案查詢入口，不保存完整的 project catalog 或固定路徑清單。
完整的專案背景、決策與 current local path 由 personal knowledge base 維護。

## Source of Truth

依序查閱：

1. `~/Project/Note/miyago-knowledge-base/AGENTS.md`
2. `~/Project/Note/miyago-knowledge-base/INDEX.md`
3. `[[wiki/conventions/workspace-directory-layout]]`：工作目錄與 current path
4. `[[wiki/projects/_MOC|Projects MOC]]`：專案節點入口
5. 對應的 `wiki/projects/<project>.md`：專案背景、證據與相關連結

## Lookup Rules

- Miyago 提到專案名稱、要求找專案或需要選擇工作目錄時，先查 personal vault，再搜尋 filesystem。
- 路徑以 `workspace-directory-layout` 與當前 filesystem / Git 驗證為準；本 skill 不保存搬移前的 path。
- 先用 `rg` 搜尋 title、aliases、tags、wikilink 與專案名稱，再讀最小必要段落。
- 讀取既有 project node 時，保留其 verified facts、inference 與 unknown 的區分。
- 若 vault 沒有對應節點，明確說明沒有足夠資料，再以 repository README、manifest、remote 與現場路徑補充。

## Knowledge Maintenance

- 只有 Miyago 明確要求，或工作產生可重用結論時才寫回 vault。
- 寫入前查重，優先更新 canonical node；新節點依 vault template 建立。
- 寫入後同步相關 MOC、`INDEX.md`、`LOG.md` 與 `## Related`。
- Vault 內使用 Obsidian wikilinks；不寫 secrets、credentials、個資或未驗證推論。
- 完成後執行：

  ```bash
  bash ~/Project/Note/miyago-knowledge-base/scripts/vault-lint.sh
  ```

## Boundaries

- `~/Project/Note/itrd-knowledge-base` 永遠唯讀。
- SRE、PMS、RiceCall 等 domain-specific 問題依 knowledge-base routing 規則轉到對應 vault。
- 本 skill 不取代 repository root 的 `AGENTS.md`、project spec 或 source code；它只負責找到正確入口與上下文。
