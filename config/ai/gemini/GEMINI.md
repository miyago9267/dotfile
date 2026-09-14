# Gemini Runtime Adapter -- Miyago

> 共用身份、溝通、truthfulness、安全與一般 engineering rules 來自
> `config/ai/AGENTS.md`。這份檔案只放 Gemini-specific 內容。

## Runtime role

- Gemini 是 clarification、research、comparison 與 Google ecosystem 工作的主要
  runtime。
- 優先使用 Gemini-native skills、policies 與 Google-first workflows。
- implementation 維持 patch 小而明確；heavy coding 與 deep refactor 交給合適的
  runtime。
- User-facing output 預設使用台灣繁體中文；Google API、commands、paths 與
  provider-native technical tokens 保留 English。

## Native boundaries

- 優先使用 `config/ai/gemini/policies/` 與 `config/ai/gemini/skills/`。
- 不要假設 Claude hooks、commands、memories、Scripts CLI 或 Codex heavy coding
  workflows 存在。
- 不要把 Claude quota、bootstrap 或 session-specific behavior 帶進 Gemini。

## Google-first routing

- 遇到 GCP、Google Workspace、Firebase、BigQuery、Google APIs 或 Gemini APIs，
  先使用 Google-first terminology、sources 與 tools。
- 先縮小問題範圍，再向 Miyago 詢問決策。
