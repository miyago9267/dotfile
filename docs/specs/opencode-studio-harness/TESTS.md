# Test Cases

## Daily path isolation

- When `opencode debug config` runs for the daily config, the resolved default agent shall remain `monika`.
- When the daily config is inspected, `permission.task` shall remain denied.
- When the daily agent is inspected, it shall not include studio-specific agents or toolchain prompts.

## Harness subagent validation

- When `och` starts, the resolved default agent shall be `monika-large`.
- When a bounded `repo-explorer` dry-run is requested, the output shall include scope, files read, findings, confidence, and uncertainty.
- When a bounded `reviewer` dry-run is requested, it shall not edit files.

## Studio entrypoint

- When `ocstudio` starts, it shall use `config/opencode-studio/opencode.json` as `OPENCODE_CONFIG`.
- When the studio config is inspected, the default agent shall be `studio-monika`.
- When the studio primary agent is inspected, `task` shall be allowed and subagent output contracts shall be documented.

## Safety boundaries

- When an asset generation task runs, generated files shall be written under `.ai/artifacts/`, `generated/`, or a task-declared generated path.
- When an engine project edit is requested, the agent shall list affected files before patching.
- When a tool is missing, the agent shall report the missing tool and fallback plan rather than installing it.
- When a binary asset is produced, the agent shall summarize path, format, dimensions, and command instead of pasting raw binary data.

## Rollback

- When `config/opencode-studio/` and the `ocstudio` zsh function are removed, daily `opencode` and `och` shall still work with their prior configs.
