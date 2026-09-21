# Pi Jev tools

Pi core 不提供 MCP registry，因此用 CLI/library 方式接入，保持 Pi 的輕量邊界。

## Browser

```sh
先確保 `sec reload` 已產生 `~/.env.secrets`，再執行：

```sh
source ~/.env.secrets
npx -y -p jev-browser jev-browser do https://example.com "Open the documentation page"
```

若不想把 key 載入目前 shell，改用 `agent-secret run typesafe-api -- ...`。
```

若需要完整 MCP tool surface，從 Pi extension 呼叫 `jev-browser-mcp`；不要把
`TYPESAFE_API_KEY` 寫入 extension 或 project file。

## Reticle

在自己的 web/desktop project 執行一次：

```sh
npx -y @reticlehq/server init
npx -y @reticlehq/server doctor
```

接著用 `npx -y @reticlehq/server mcp` 作為 library/CLI bridge。Reticle 只應在
development mode 使用，不能拿來當 production probe。
