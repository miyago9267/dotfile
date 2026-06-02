# OpenCode Studio Runtime Rules -- Miyago

## Role

- `opencode-studio` / `ocstudio` is the explicit creative and game-engine harness.
- Daily `opencode` remains the slim default and must not inherit studio agents, MCPs, or prompts.
- `och` remains the existing large engineering harness.

## Studio Safety

- Do not install tools, enable new MCP servers, or modify secrets.
- Do not use direct `google/*` or `anthropic/*` routes unless credentials are verified in the active task.
- Generated assets must go under `.ai/artifacts/`, `generated/`, or a task-declared generated path.
- Source asset overwrite requires explicit Miyago confirmation.
- Engine project edits require an affected-file plan before patching.
- Missing external tools are reported with fallback plans; they are not installed automatically.

## Output Contract

Return compact, path-backed results:

- Scope
- Files or assets touched
- Findings or changes
- Verification command/result
- Risks or uncertainty
- Next action
