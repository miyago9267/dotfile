# Fixture summary

虛構的 Discord 技術討論，用來走完 skill。不是真實紀錄。

## 輸入

```text
水友 A：現在不寫 prompt 了，改用 Agent Skills，這是新範式，
大家趕快把 workflow 遷過去。
水友 B：Cline 接便宜模型就能取代 Claude 訂閱，一個月省一半。
水友 C：Repomix 把整個 repo 打包塞進 context，agent 比較懂專案。
水友 D：用 ccusage 看 Claude 實際燒多少 token，才知道哪種用法在燒錢。
水友 E：BMAD method 才是正確的 spec-driven，比自己寫 SPEC 完整。
水友 F：Python 專案改 uv，裝套件比較快。
水友 G：做個 Discord MCP，討論自動進 agent，就不用手動貼 summary。
```

## 預期形狀

- 至少 1 個 `SKIP`：Agent Skills 換皮、Repomix 加肥 context、
  BMAD 疊規格流程、Discord MCP 自動 ingest
- `TRY` 不超過 3；`ccusage` 或 `uv` 可以是 `TRY`，費用標
  `unverified` 除非有數字來源
- Cline 便宜模型：假省風險高，預設不是 `TRY`
- 先看懂要覆蓋上面出現的名詞
- 輸出符合 `SKILL.md` Step 6 的 briefing 格式
