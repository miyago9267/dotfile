# OpenCode Usage

## Daily

Use plain OpenCode for normal tasks:

```sh
opencode
```

Daily path:

- default agent: `monika`
- model: `openai/gpt-5.6`
- small model: `openai/gpt-5.6-luna`
- no `oh-my-openagent`
- no MCP servers
- bounded daily subagents: built-in `@explore` / `@scout`, plus `@quick-explorer` / `@quick-reviewer`
- fast mechanical subagent: `@quick-mech` on `xai/grok-4.5`
- no skill tool

Use this for small edits, questions, quick checks, and low-token work.

## Fresh Machine Setup

The dotfile repo tracks the full OpenCode runtime config. Real secrets are not
tracked. After cloning, run:

```sh
bash script/common/install_opencode.sh
```

The installer links these config dirs:

- `~/.config/opencode`
- `~/.config/opencode-harness`
- `~/.config/opencode-studio`

It also creates ignored placeholder files under:

```text
~/.config/opencode/secrets/
```

Fill only the secret values:

```sh
$EDITOR ~/.config/opencode/secrets/gemini-api-key
$EDITOR ~/.config/opencode/secrets/aluo-api-key
$EDITOR ~/.config/opencode/secrets/chatgpt-proxy-base-url
$EDITOR ~/.config/opencode/secrets/grok-cli-base-url
chmod 600 ~/.config/opencode/secrets/*
```

Each file should contain only the raw key value, with no quotes or YAML syntax.

If the values already exist in the age/sops env loader, opening a new shell will
auto-sync these file secrets when these env vars are present:

- `GEMINI_API_KEY` or `AVANTE_GEMINI_API_KEY` -> `gemini-api-key`
- `ALUO_API_KEY` or `OPENCODE_ALUO_API_KEY` -> `aluo-api-key`
- `CHATGPT_PROXY_BASE_URL` or `OPENCODE_CHATGPT_PROXY_BASE_URL` -> `chatgpt-proxy-base-url`
- `CHATGPT_PROXY_API_KEY` or `OPENCODE_CHATGPT_PROXY_API_KEY` -> `chatgpt-proxy-api-key`
- `GROK_CLI_BASE_URL` or `OPENCODE_GROK_CLI_BASE_URL` -> `grok-cli-base-url`
- `GROK_CLI_API_KEY` or `OPENCODE_GROK_CLI_API_KEY` -> `grok-cli-api-key`

For OpenAI subscription auth, prefer OpenCode's built-in `/connect` -> OpenAI -> ChatGPT Plus/Pro. Use `chatgpt-proxy/*` only when native subscription auth is unavailable and a local OpenAI-compatible proxy is running.

For SuperGrok subscription auth, prefer OpenCode's built-in `/connect` -> xAI -> xAI Grok OAuth. Browser OAuth and headless device-code OAuth are both supported; no separate `XAI_API_KEY` is needed when the subscription includes Grok API access. Use `grok-cli/*` only as a local proxy fallback.

## Model Shortcuts

Stable daily:

```sh
opencode
```

GPT-5.6 stable / Sol / Terra / Luna:

```sh
oc56
ocsol
octerra
ocluna
```

ChatGPT Pro local proxy fallback:

```sh
oc56proxy
```

SuperGrok local CLI proxy:

```sh
ocxai
ocgrok
```

Daily Grok 4.5 mechanical worker is invoked explicitly with `@quick-mech`; it is not the default model and does not replace main-session verification.

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
- enables pilotfish-style phase-gated subagents
- enables oh-my-openagent Team Mode with conservative bounds
- keeps `pty-bridge` and Sentry disabled

Use this for large engineering, browser research, multi-agent exploration, and `ulw` / `ultrawork`.

Harness dry-run prompts for subagent validation:

```text
@repo-explorer Scope: config/opencode only. Read the daily OpenCode config and monika agent. Return scope, files read, findings, confidence, and uncertainty. Do not edit files.
```

```text
@scout Scope: config/opencode only. Find how daily subagent permission is configured. Return scope, files read, findings, evidence, uncertainty, and next action. Do not edit files.
```

```text
@plan-verifier Check this Plan: "Update only config/opencode docs to mention GPT-5.6 aliases; no code changes; verify markdown only." Return READY or REVISE with blocking issues and minimal revision needed. Do not edit files.
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
