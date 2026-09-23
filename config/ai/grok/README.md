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

## Runtime layers

Grok has two explicit launchers:

- `grok-native` -- strict native mode. It uses a private process `HOME`, keeps
  Grok state/auth in `GROK_HOME`, and disables Claude compatibility cells.
- `grok-compat` -- opt-in compatibility mode. It uses the normal `HOME` and
  explicitly enables Claude compatibility cells.

Run `bash script/common/setup_grok.sh` after pulling the dotfiles. It links the
native persona adapter to `$GROK_HOME/AGENTS.md` and installs both launchers in
`~/.local/bin`. The bare `grok` command is intentionally left untouched.

Pilotfish orchestration is deliberately separate. Review and install the
pinned package at `plugins/pilotfish-grok/` with its own
`install/AGENT-INSTALL.md`; `setup_grok.sh` does not merge its roles or policy
into the root `AGENTS.md`.

The native adapter is required because Grok does not execute Claude's
SessionStart hooks. The Claude-compatible `~/.claude/Claude.md` therefore
cannot be the only source of Monika's identity.

## Claude compatibility boundary

Claude compatibility is not the shared persona source. Keep it disabled for
normal Grok work and enable it only through `grok-compat` when a session
actually needs Claude content.

`compat.claude.agents = false` does not currently gate `.claude/agents`
subagent discovery. Native mode handles this product gap by isolating the
process `HOME`; it does not move or modify Claude's own agent directory.

Grok's compatibility discovery currently loads the existing Claude-compatible
surface. `grok inspect --json` confirmed:

- `human-voice` is enabled.
- Source: `~/.claude/skills/human-voice/SKILL.md`.
- Repository source: `config/ai/claude/skills/human-voice/SKILL.md`.
- The source remains managed by `script/common/setup_claude.sh`.
- The same inspection also reported broader Claude-compatible global rules,
  hooks, skills, and agents as loaded.

Grok's user config currently points `[skills].paths` at
`config/ai/codex/skills`, so those explicitly configured skills remain available
in native mode. This path is an approved shared-skill boundary; Claude-native
skills are not used as the persona source.

## Still unverified

- OAuth/device login has not been run; credentials remain user-owned.
- Free-trial eligibility and account limits require Miyago's own Grok account
  flow and are not assumed from the installer.
- Grok host lifecycle recap equivalence is not established. Until verified, the
  agent fallback recap remains required after meaningful work.
- Tool, working-directory, and project-trust behavior need a post-login smoke
  test before claiming full runtime parity.
- Native and compatibility discovery have been verified with `inspect`, but a
  real external prompt has not been sent as part of this setup.

## Activation boundary

The native adapter and launchers are safe to install before login because they
contain no credentials or machine-local state. Use `grok-native` for normal
work. Use `grok-compat` only when Claude compatibility is intentional. Do not
add credentials, provider routing, shell hooks, or machine-local state to this
repository.
