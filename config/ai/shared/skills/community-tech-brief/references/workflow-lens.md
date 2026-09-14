# Workflow lens

給 `community-tech-brief` 用的打分鏡頭。不是技術百科。
改工作流時才改這份檔，不要從 Discord 熱詞自動更新。

## 現有面

- Agent：Claude / Codex / Grok / Gemini；skill、hook、MCP
- 編輯：Neovim
- 產品棧：TypeScript、Bun、Vue 3、Hono、Go、Python
- SRE：Docker、Kubernetes、GCP
- 知識：local Obsidian vault，經 `knowledge-base-router`

## 費用面

點名是哪一張帳單，沒證據就 `unverified`：

- token：context 肥、重複搜索、無謂 subagent
- 訂閱：Claude / Codex / Grok / Gemini / 雲端
- 時間：多一套要養的流程或 runtime
- infra：GCP / 叢集 / 多餘的服務

一次貴但穩，通常比反覆用便宜方案修正划算。
會增加 retry、維護層、context 的「省錢」算假省。

## 五個測試

1. 這都是基本？只換皮 -> `SKIP`
2. 重疊？已有 skill / hook / MCP / CLI 做同一件事 -> `SKIP`
3. 對得上上面的現有面與真實痛點？對不上 -> `WATCH` 或 `SKIP`
4. 費用主張可檢驗？能在一週內證偽才考慮 `TRY`
5. 採用稅：新 runtime、新訂閱、context 變肥、多一套抽象。
   稅高且收益不明 -> `SKIP`

## 重疊速查

只對 skill **名字**，不讀本文：

- session 浪費：`efficiency`、`search-discipline`、
  `context-prompt-discipline`
- 自己的 traces：`learn`
- 找現成 skill：`find-skills`
- 專案知識：`knowledge-base-router`
- 產 skill / prompt：`skill-maker`、`prompt-smith`
- 規格與測試：`auto-spec`、`sdd`、`tdd`
- 維運：`docker-k8s`、`health-check`、`log-analysis`、`sre-locate`

## 裁決

- `TRY`：對得上痛點，且有一天內的最小實驗
- `WATCH`：可能有用，但沒痛、證據弱、或還在炒
- `SKIP`：已有、換皮、加抽象、假省錢、離棧太遠
