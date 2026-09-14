# Test Cases

## Build

- When `config/ai/claude-plugin/scripts/build-artifact.sh` runs, the system shall recreate `plugins/monika-claude/`.
- When build completes, the artifact shall include `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `install.sh`, `skills/`, `commands/`, and `templates/`.

## Validation

- When `config/ai/claude-plugin/scripts/validate-artifact.sh` runs, the system shall confirm the artifact uses the `monika-claude` name in generated metadata.
- When `script/common/install_claude.sh` runs on a machine with Claude CLI already present, the system shall still rebuild and install the Claude plugin automatically.

## Runtime decomposition

- When the dotfile Claude settings are loaded, `dev-discipline` shall be
  absent from both enabled plugins and known marketplaces.
- When the native Claude runtime is loaded, its settings and component links
  shall resolve to the dotfile-managed `config/ai/claude/` tree.

## Smoke

- When `bash plugins/monika-claude/install.sh --export` runs, the system shall print the project `AGENTS.md` template.
- When `bash plugins/monika-claude/install.sh --project <tmpdir>` runs, the system shall create `AGENTS.md` plus SDD template files in the target directory.
