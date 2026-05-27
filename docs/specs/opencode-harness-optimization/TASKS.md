---
id: tasks-opencode-harness-optimization
spec: spec-opencode-harness-optimization
created: 2026-05-27
updated: 2026-05-27
status: archived
---

# Tasks

## P0: Baseline, Safety, and Reversibility

- [x] Capture `opencode debug config` output before optimization
- [x] Capture `opencode models` and provider availability before optimization
- [x] Capture `opencode stats` before first real harness use
- [x] Verify OpenCode config remains symlinked from dotfiles
- [x] Verify plugin package artifacts are ignored and not committed
- [x] Add or verify OpenCode share/privacy setting
- [x] Add or verify watcher/ignore rules for generated, secret, and noisy directories
- [x] Keep unsupported direct `google/*` and `anthropic/*` routes disabled

## P1: Prompt Diet

- [x] Create slim daily OpenCode agent prompt
- [x] Route normal tasks to slim agent instead of full `Sisyphus`
- [x] Keep `oh-my-openagent` heavy agents behind explicit large-task commands
- [x] Move `oh-my-openagent` out of the default `opencode` path and into explicit `opencode-harness`
- [x] Move MCP/browser servers out of the default `opencode` path and into explicit `opencode-harness`
- [x] Document daily vs harness entrypoints
- [x] Audit duplicate instructions across `AGENTS.md`, `opencode.json`, plugin prompts, and skills
- [x] Reduce or isolate full `~/.claude/skills` prompt exposure
  - Current mitigation: OpenCode skill permission is deny-by-default with a small allowlist.
  - Default `monika` has `skill: deny`; harness `monika-large` keeps only a small skill allowlist.
- [x] Disable the skill tool for the default daily `monika` agent
- [x] Re-run `opencode debug config` and inspect resolved prompt surface

## P2: Subagent Strategy

- [x] Define task-size routing rules in OpenCode `AGENTS.md`
- [x] Define subagent output contract
- [x] Add or configure `repo-explorer`
- [x] Add or configure `vault-librarian`
- [x] Add or configure `browser-crawler`
- [x] Add or configure `implementation-worker`
- [x] Add or configure `reviewer`
- [x] Dry-run a large multi-subagent task and verify subagent summaries do not flood the main session
  - Archived decision: browser-crawler single-subagent dry-run passed. Full large-task simulation is deferred until the first real large task because it is not an activation blocker and would spend unnecessary tokens.

## P3: MCP and Browser Crawler

- [x] Evaluate browser crawler MCP options
- [x] Configure preferred browser MCP with page/depth limits
- [x] Evaluate docs/context MCP options
- [x] Evaluate GitHub MCP/plugin usage boundary
- [x] Add source-citation and summary contract for crawler outputs
- [x] Dry-run crawler on a documentation page and verify bounded output

## P4: Plugin Evaluation

- [x] Evaluate `opencode-snip`
- [x] Evaluate `Context Analysis`
- [x] Evaluate `Dynamic Context Pruning`
- [x] Evaluate `Envsitter Guard`
- [x] Evaluate `Opencode Ignore`
- [x] Evaluate `Opencode Quota` or `opencode-mystatus`
- [x] Defer mega-orchestration plugins until P0/P1/P2 are stable

## Validation

- [x] Small task completes without subagent fan-out
- [x] Medium task uses at most one or two bounded subagents
- [x] Large task uses subagents with compact evidence summaries
  - Archived decision: validated through bounded `browser-crawler` task output contract; multi-agent expansion will be verified during first real large task.
- [x] Browser crawler respects scope and cites canonical URLs
- [x] Token/context observability is available during real sessions
