# ULW Handoff: OpenCode Studio Harness

## Goal

Implement Phase 1 and Phase 2 of `docs/specs/opencode-studio-harness/` so OpenCode gains a separate studio harness for creative and game-engine tasks without increasing daily `opencode` fixed context cost.

## Read first

- `docs/specs/opencode-studio-harness/SPEC.md`
- `docs/specs/opencode-studio-harness/TASKS.md`
- `docs/specs/opencode-studio-harness/TESTS.md`
- `config/opencode/opencode.json`
- `config/opencode/agents/monika.md`
- `config/opencode-harness/opencode.json`
- `config/opencode-harness/agents/monika-large.md`
- `config/zsh/.zshrc.d/opencode.zsh`

## Scope

Implement only:

1. Phase 1: harness/subagent dry-run documentation and validation plan.
2. Phase 2: `config/opencode-studio/` skeleton and `ocstudio` entrypoint.

Do not implement Phase 3-5 yet.

## Required behavior

- Daily `opencode` remains slim and keeps task/subagent disabled.
- `och` remains the existing large engineering harness.
- New `ocstudio` entrypoint uses separate `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`.
- Studio config default agent is `studio-monika`.
- Studio agents exist:
  - `art-director`
  - `asset-worker`
  - `multimodal-looker`
  - `game-engine-worker`
  - `technical-artist`
  - `qa-playtester`
- New external MCP/API/tool integrations are disabled by default or documented as future work.
- Rollback path is documented.

## Constraints

- Do not install new tools.
- Do not modify secrets.
- Do not enable direct `google/*` or `anthropic/*` routes unless credentials are verified.
- Do not make daily `opencode` heavier.
- Do not remove existing `och` / `ulw` behavior.
- Do not allow asset workers to overwrite source assets by default.

## Suggested implementation

1. Add `config/opencode-studio/opencode.json` with separate default agent and conservative provider/model choices.
2. Add `config/opencode-studio/AGENTS.md` with studio-specific global rules.
3. Add `config/opencode-studio/agents/studio-monika.md` as primary router.
4. Add studio subagents with tight permission boundaries and compact output contracts.
5. Add `ocstudio()` to `config/zsh/.zshrc.d/opencode.zsh`.
6. Update `config/opencode/USAGE.md` or create `config/opencode-studio/USAGE.md` with invocation and rollback instructions.
7. Update `TASKS.md` for completed Phase 1-2 items.

## Verification

Run non-destructive checks only:

```bash
source ~/.zshrc 2>/dev/null
opencode debug config
OPENCODE_CONFIG="$HOME/.config/opencode-harness/opencode.json" OPENCODE_CONFIG_DIR="$HOME/.config/opencode-harness" opencode debug config
OPENCODE_CONFIG="$HOME/.config/opencode-studio/opencode.json" OPENCODE_CONFIG_DIR="$HOME/.config/opencode-studio" opencode debug config
zsh -n config/zsh/.zshrc.d/opencode.zsh
```

If studio symlink setup is needed, add the minimal setup script change and document it.

## Output contract

Return:

- Scope completed
- Files changed
- Validation commands and results
- Any config/schema uncertainty
- Remaining Phase 3-5 tasks
- Recommended next action
