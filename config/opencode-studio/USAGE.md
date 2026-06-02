# OpenCode Studio Usage

## Entry

Use the studio harness only for creative, asset, multimodal, or game-engine work:

```sh
ocstudio
```

The entrypoint sets:

```sh
OPENCODE_CONFIG="$HOME/.config/opencode-studio/opencode.json"
OPENCODE_CONFIG_DIR="$HOME/.config/opencode-studio"
```

## Studio Path

- default agent: `studio-monika`
- subagents: bounded studio roles only
- model route: OpenAI by default
- oh-my-openagent plugin: not loaded in studio, to keep non-studio agents out of the resolved prompt
- Playwright MCP: configured but disabled by default
- new external MCP/API/tool integrations: disabled or future work
- generated assets: `.ai/artifacts/`, `generated/`, or a task-declared generated path

## Studio docs

- `TOOLCHAIN.md`: detection-only tool capability matrix and fallback policy.
- `PROMPTS.md`: reusable workflow prompts for reference analysis, assets, Godot, shader/VFX, and QA.
- `DEMOS.md`: demo and benchmark plan for Phase 5 validation.

## Validation

Non-destructive checks:

```sh
source ~/.zshrc 2>/dev/null
opencode debug config
OPENCODE_CONFIG="$HOME/.config/opencode-harness/opencode.json" OPENCODE_CONFIG_DIR="$HOME/.config/opencode-harness" opencode debug config
OPENCODE_CONFIG="$HOME/.config/opencode-studio/opencode.json" OPENCODE_CONFIG_DIR="$HOME/.config/opencode-studio" opencode debug config
zsh -n config/zsh/.zshrc.d/opencode.zsh
```

If `~/.config/opencode-studio` is missing, re-run the dotfile setup after confirming it is safe in this repo.

Latest non-secret validation results from the repo path:

- JSON parse: `config/opencode/opencode.json`, `config/opencode-harness/opencode.json`, and `config/opencode-studio/opencode.json` parsed successfully.
- Daily isolation: with `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` unset, `opencode debug config` resolved `default_agent=monika` and `permission.task=deny`.
- Harness preservation: with repo-path harness env vars, `opencode debug config` resolved `default_agent=monika-large`; Playwright remained enabled for the existing harness path.
- Studio config: with repo-path studio env vars, `opencode debug config` resolved `default_agent=studio-monika`, `studio-monika.permission.task=allow`, all six studio subagents present, no oh-my-openagent extra agents, and `mcp.playwright.enabled=false`.
- Entrypoint: `zsh -n config/zsh/.zshrc.d/opencode.zsh` passed, and `ocstudio` forced the studio config even when inherited `OPENCODE_CONFIG` values were set.
- Installed-home check: the exact `$HOME/.config/opencode-studio` debug command failed in this checkout because the symlink is not installed yet; `script/common/setup_dotfiles.sh` now links `config/opencode-studio` to `~/.config/opencode-studio`.
- Installed-home check: after running `bash script/common/setup_dotfiles.sh`, `$HOME/.config/opencode-studio` exists and `opencode debug config` passes with the studio config.
- Harness subagent dry-run: `@repo-explorer` completed against `config/opencode`, returned scope/files/findings/confidence/uncertainty, and did not edit files.
- Harness reviewer dry-run: `@reviewer` reviewed the current diff, returned findings/test gaps/suggested fix order, and did not edit files.

## Rollback

Remove the studio harness with:

1. Delete `config/opencode-studio/`.
2. Remove `ocstudio()` from `config/zsh/.zshrc.d/opencode.zsh`.
3. Remove the `~/.config/opencode-studio` link or re-run setup after reverting the link.

Daily `opencode` and `och` do not depend on this directory.
