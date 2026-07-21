---
name: grok-human-voice-adapter
status: installed-unverified
runtime-scope: grok-compatible
---

# Grok Human-Voice Adapter Contract

Grok CLI `0.2.106` is installed locally from the inspected xAI installer at
`https://x.ai/cli/install.sh`. The installer wrote `~/.grok/` and linked `grok`
and `agent` into `~/.local/bin`; it was run with `SHELL=/bin/none`, so it did
not modify `~/.zshrc`.

## Current integration path

Grok's compatibility discovery currently loads the existing Claude-compatible
skill surface. `grok inspect --json` confirmed:

- `human-voice` is enabled.
- Source: `~/.claude/skills/human-voice/SKILL.md`.
- Repository source: `config/ai/claude/skills/human-voice/SKILL.md`.
- The source remains managed by `script/common/setup_claude.sh`.
- The same inspection also reported broader Claude-compatible global rules,
  hooks, skills, and agents as loaded.

No separate Grok copy is created while the CLI consumes this compatible path.
Grok's user config now also points `[skills].paths` at
`config/ai/codex/skills`, so Codex-native skills are available through Grok's
supported extra-skill-path mechanism. The shared contract and the Claude/Codex
skills remain the semantic source of truth; Grok-specific files must not fork
their delivery rules. The broader compatibility import must be isolated or
explicitly accepted before sending private context to a Grok session.

## Still unverified

- OAuth/device login has not been run; credentials remain user-owned.
- Free-trial eligibility and account limits require Miyago's own Grok account
  flow and are not assumed from the installer.
- Grok host lifecycle recap equivalence is not established. Until verified, the
  agent fallback recap remains required after meaningful work.
- Tool, working-directory, and project-trust behavior need a post-login smoke
  test before claiming full runtime parity.
- The compatibility surface currently appears broader than `human-voice`; do
  not authenticate or run private-work prompts until that import scope is
  isolated or explicitly accepted.

## Activation boundary

Before login, isolate or review the broader compatibility import. After that,
run a sanitized smoke test and inspect the discovered instruction surface before
adding any Grok-specific adapter. Do not add credentials, provider routing, shell
hooks, or machine-local state to this repository.
