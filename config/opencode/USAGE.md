# OpenCode Usage

## Daily

Use plain OpenCode for normal tasks:

```sh
opencode
```

Daily path:

- default agent: `monika`
- model: `openai/gpt-5.5`
- small model: `openai/gpt-5.4`
- no `oh-my-openagent`
- no MCP servers
- no subagent task tool
- no skill tool

Use this for small edits, questions, quick checks, and low-token work.

## Model Shortcuts

Stable daily:

```sh
opencode
```

GPT-5.4 high for chores:

```sh
oc54h
```

DeepSeek v4 Flash benchmark path:

```sh
ocds
```

Copilot Opus emergency fallback, only after GPT and DeepSeek are exhausted or explicitly requested:

```sh
ocop
```

## Harness

Use the explicit harness entry for large work:

```sh
opencode-harness
```

Short alias:

```sh
och
```

Harness path:

- default agent: `monika-large`
- loads `oh-my-openagent`
- enables Playwright MCP and existing research/code MCPs
- enables bounded subagents
- enables oh-my-openagent Team Mode with conservative bounds
- keeps `pty-bridge` and Sentry disabled

Use this for large engineering, browser research, multi-agent exploration, and `ulw` / `ultrawork`.

Harness dry-run prompts for subagent validation:

```text
@repo-explorer Scope: config/opencode only. Read the daily OpenCode config and monika agent. Return scope, files read, findings, confidence, and uncertainty. Do not edit files.
```

```text
@browser-crawler Question: Read one official OpenCode configuration documentation page. Max pages 1, max depth 0. Return URLs read, findings, source-backed evidence, and what was not verified. Do not edit files.
```

```text
@reviewer Review the current diff for config safety and regression risk. Return findings, open questions, test gaps, and suggested fix order. Do not edit files.
```

Team Mode bounds:

- enabled only in `opencode-harness`
- max members: 6
- max parallel members: 3
- max wall clock: 90 minutes
- tmux visualization: off by default

## Ultrawork

Interactive:

```sh
och
```

Then type:

```text
ultrawork <task>
```

CLI shortcut:

```sh
ulw "<task>"
```

Alias:

```sh
ultrawork "<task>"
```

This launches the harness path with `Sisyphus - ultraworker` and the built-in `/ulw-loop` command. It should be reserved for real large tasks because it enables aggressive orchestration and has higher fixed token cost.

## Token Baseline

Last local dry-runs:

- daily `monika-ready`: about `6.1K` input tokens
- harness `harness-ready`: about `21.8K` input tokens
- harness `@browser-crawler` one-page MCP docs fetch: bounded output, used one subagent, about `22.1K` first-step input tokens

The daily path is the default because the harness path has materially higher fixed context cost.
