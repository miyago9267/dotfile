# monika-codex packaging source

這個目錄是 `monika-codex` Codex plugin 的 source tree。

## Source of truth

- shared contract: `config/ai/AGENTS.md`
- Codex adapter: `config/ai/codex/AGENTS.md`
- packaging metadata: `config/ai/codex-plugin/plugin.json`
- skill allowlist: `config/ai/codex-plugin/skills-allowlist.txt`

## Build

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/codex-plugin/scripts/build.sh
```

## Validate

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/codex-plugin/scripts/validate.sh
```

## Output

- plugin artifact: `plugins/monika-codex/`
- local marketplace: `.agents/plugins/marketplace.json`
