# Test Cases

## Build

- When `config/ai/codex-plugin/scripts/build.sh` runs, the system shall recreate `plugins/monika-codex/` without manual edits.
- When build completes, the system shall write `.codex-plugin/plugin.json`, `skills/`, `templates/`, and `scripts/`.

## Composition

- When `scripts/export-agents.sh` runs from the plugin artifact, the system shall print a composed `AGENTS.md`.
- When `scripts/project-init.sh <dir>` runs, the system shall create `AGENTS.md` and copy spec templates into `<dir>/docs/specs/_templates/`.
- When `scripts/install-local.sh` runs, the system shall copy the plugin to `~/plugins/monika-codex` and ensure `~/.agents/plugins/marketplace.json` contains the plugin entry.

## Marketplace

- When the local marketplace file is inspected, the system shall contain one `monika-codex` plugin entry with `source.path` set to `./plugins/monika-codex`.

## Validation

- When `config/ai/codex-plugin/scripts/validate.sh` runs, the system shall confirm required files exist in the generated artifact.
