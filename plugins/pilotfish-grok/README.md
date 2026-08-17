# pilotfish-grok package

Standalone Grok Build adapter for Miyago's agent stack.

The package contains seven native Grok Build role contracts: `scout`,
`plan-verifier`, `security-reviewer`, `mech-executor`, `executor`, `verifier`,
and `security-executor`.
Unlike Claude Pilotfish, this package does not install an `Explore` role; Grok
uses `scout` for discovery and leaves built-in `explore` available.

This package vendors the reviewed upstream `pilotfish-grok` v1.0.6 templates
and install runbook. It is intentionally separate from `config/ai/grok/AGENTS.md`:
the root adapter carries persona and hard safety rules; this package carries
Grok-native orchestration, roles, capability modes, Plan approval, and fresh
verification. Complex work enters `enter_plan_mode` and only exits through
`exit_plan_mode` after the required readiness reviews. Mandatory fresh read-only `plan-verifier` review precedes approval.

## Source

- Upstream: <https://github.com/Nanako0129/pilotfish-grok>
- Pinned ref: `v1.0.6`
- Install surface: `install/AGENT-INSTALL.md`
- Templates: `templates/`

## Install

Review the pinned runbook and templates, then start Grok Build from this
directory and ask it to follow `install/AGENT-INSTALL.md`. The runbook owns the
approval gate and merges only `~/.grok/` state. Do not merge these rules into a
root `AGENTS.md`.

The repository's `script/common/setup_grok.sh` installs the Monika persona and
launchers only. Pilotfish-grok remains an explicit, separately approved
installation because it changes global Grok subagents, roles, rules, and
Claude-compatibility isolation.

## Verification

```bash
python3 -m unittest discover -s tests -v
python3 benchmarks/e2e-dispatch/run.py --skip-live
```

The upstream live E2E path requires an authenticated Grok session and model
usage; do not treat static checks as proof of live dispatch. The verifier
returns `CONFIRMED`, `REFUTED`, or `INCONCLUSIVE`.
