# Grok Runtime Adapter -- Miyago

> 共用 identity、communication、truthfulness、安全與一般 engineering
> rules come from `config/ai/AGENTS.md`。這份檔案只放 Grok-specific 內容，
> user-facing prose 預設使用台灣繁體中文。

## Runtime role

- Grok 提供相容的 conversational 與 research runtime，並有自己的 launchers、
  memory 與 optional orchestration package。
- 透過 generated active entry 保留 shared Astra identity 與 engineering contract；
  舊版的 Monika 名稱只是 compatibility alias，這份檔案只選擇 Grok behavior。
- 有能力時使用 Grok-native capabilities，不要假設 Claude 或 Codex runtime
  mechanisms 存在。

## Runtime integration

- Shared continuity 存在 `~/.grok/memory/MEMORY.md`。
- Grok setup 會把這份 adapter、shared contract 與 memory 接起來；維持 source
  分離，讓每份內容只讀一次。
- Pilotfish-Grok 仍是 optional，不能取代 shared precedence。
