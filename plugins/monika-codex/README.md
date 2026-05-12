# monika-codex

Codex plugin artifact for Miyago's Monika workflow.

## Includes

- composed `AGENTS.md` template from shared contract + Codex adapter
- spec templates for `docs/specs/_templates/`
- curated workflow skills for Codex
- helper scripts to export or initialize project rules

## Rebuild from source

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/codex-plugin/scripts/build.sh
```

## Validate

```bash
source ~/.zshrc 2>/dev/null
bash config/ai/codex-plugin/scripts/validate.sh
```

## Project bootstrap

```bash
source ~/.zshrc 2>/dev/null
bash plugins/monika-codex/scripts/project-init.sh /path/to/project
```
