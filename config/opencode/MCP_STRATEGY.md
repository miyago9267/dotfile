# OpenCode MCP Strategy

## Default Policy

- MCP servers must have a named purpose, owner, and disable path.
- Browser or crawler MCP use must be bounded by page count, depth, domain, and output size.
- Prefer official documentation and primary sources.
- Do not expose broad remote MCP servers by default.

## Browser Crawler Contract

Defaults:

- Max pages: 5
- Max depth: 1
- Same-domain unless explicitly expanded
- Deduplicate URLs
- Summarize instead of pasting raw pages

Every crawler result must include:

- URLs read
- Retrieval date
- Findings
- Source-backed evidence
- Unverified gaps

## Candidate MCP Classes

| Class | Use | Initial State |
| --- | --- | --- |
| Browser / Playwright | Interactive docs, changelogs, login-gated pages when allowed | Evaluate |
| Docs / Context lookup | Library docs and API references | Evaluate |
| GitHub | PR, issue, review, and CI context | Use only for GitHub tasks |

## Current Config

- Default `opencode`: no MCP servers, to keep daily sessions small.
- `opencode-harness`: MCP/browser layer is enabled for explicit large or research-heavy tasks.
- `playwright`: local MCP via `npx -y @playwright/mcp@latest`, enabled only in the harness path.
- `context7`: available in the harness path from existing OpenCode / oh-my-openagent resolved config.
- `websearch`: available in the harness path from existing resolved config.
- `pty-bridge`: disabled in OpenCode because Claude may already own the singleton process.
- `sentry:sentry`: disabled until OAuth is explicitly configured.

## OpenCode Config Shape

OpenCode supports local MCP servers with:

```json
{
  "mcp": {
    "example": {
      "type": "local",
      "command": ["npx", "-y", "example-mcp"],
      "enabled": false,
      "timeout": 5000
    }
  }
}
```

Sources:

- <https://opencode.ai/docs/mcp-servers/>
- <https://opencode.ai/docs/config/>
- <https://playwright.dev/docs/getting-started-mcp>
