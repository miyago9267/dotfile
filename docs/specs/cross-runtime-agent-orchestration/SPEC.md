---
id: spec-cross-runtime-agent-orchestration
title: Cross-Runtime Agent Orchestration and Agy Permission Routing
status: implemented
created: 2026-09-15
updated: 2026-09-15
author: Miyago
tags: [agents, agy, antigravity, orchestration, permissions, hooks]
priority: high
---

<!-- markdownlint-disable MD025 -->

# Cross-Runtime Agent Orchestration and Agy Permission Routing

## Requirements

- Low-risk local inspection and approved orchestration messages shall run in
  `agy` without repeated interactive permission prompts.
- Production, credential, external-publish, destructive, browser-actuation,
  schedule, MCP, and terminal-injection operations shall retain an explicit
  permission gate.
- The permission and hook configuration shall have one canonical source under
  `config/ai/` and be reproducibly deployed to `~/.gemini/`.
- Cross-runtime work shall prefer `Orca orchestration` plus background CLI/API
  workers, with structured task and completion boundaries.
- Completion requires a successful one-way and reverse-direction read-only
  smoke test, plus static validation of the deployed configuration.

## Architecture / Plan

### Decisions

- **Decision:** Use `Orca orchestration` as the coordination plane and keep
  provider-native permission engines in charge of each worker.
  - **Reason:** This removes foreground UI coupling without granting one
    runtime unrestricted control over another.
  - **By:** Miyago (2026-09-15)
- **Decision:** Allow only low-side-effect command prefixes and orchestration
  control-plane messages in the first agy permission set.
  - **Reason:** A global command wildcard would also allow credential access,
    destructive shell operations, and accidental terminal injection.
  - **By:** Miyago (2026-09-15)
- **Decision:** Remove the global agy `PreToolUse` hook that always returns
  `ask`; keep invocation and post-tool reporting hooks.
  - **Reason:** Native allow/ask/deny rules can then decide per operation
    without losing the existing Orca lifecycle reporting paths.
  - **By:** Miyago (2026-09-15)
- **Decision:** Make the cross-runtime runner host-side and read-only by
  default; do not silently escalate a provider sandbox to launch another
  runtime.
  - **Reason:** agy starts a local language server and writes its own logs;
    a restrictive Codex `read-only` sandbox cannot provide those capabilities.
    The boundary must remain visible instead of being bypassed.
  - **By:** Miyago (2026-09-15)
- **Decision:** Treat a provider-reported agy `denied_actions` result as a
  failed job even when the CLI process exits zero.
  - **Reason:** A process exit alone is not proof that the requested tool
    action happened.
  - **By:** Miyago (2026-09-15)

### Phases

1. **Permission and hook baseline:** Canonicalize agy settings, add safe
   allow/ask/deny rules, remove the all-tool confirmation hook, and deploy.
2. **Background runner contract:** Add a bounded cross-runtime runner with
   structured input/output and fixed workspace/command boundaries. **Done.**
3. **Bidirectional smoke proof:** Verify Codex to agy and agy to Codex with
   read-only tasks, no foreground UI, and recorded exit/result signals.
   **Done.**
4. **Lifecycle hardening:** Add completion, failure, timeout, and rollback
   handling without moving high-side-effect actions outside the gate. **Done.**

## Tasks

- [x] Phase 1: Permission and hook baseline
- [x] Phase 2: Background runner contract
- [x] Phase 3: Bidirectional read-only smoke proof
- [x] Phase 4: Lifecycle hardening

## Files

- `config/ai/gemini/antigravity-cli/settings.json` - canonical agy
  permissions and trusted workspace list
- `config/ai/gemini/hooks.json` - canonical agy/Orca lifecycle hooks
- `script/common/setup_gemini.sh` - deployment of agy settings and hooks
- `config/ai/runtime-bindings.yaml` - runtime source/target mapping
- `docs/specs/cross-runtime-agent-orchestration/SPEC.md` - plan and acceptance
- `script/utils/agent-call` - bounded read-only provider runner and job lifecycle
- `script/common/test_agent_call.sh` - runner regression checks
- `script/utils/README.md` - user-facing runner entry point
- `config/ai/gemini/GEMINI.md` - Gemini runtime routing for the runner
- `config/ai/codex/USAGE.md` - Codex runtime routing for the runner

## Verification

- `jq empty config/ai/gemini/antigravity-cli/settings.json
  config/ai/gemini/hooks.json` passed.
- `bash -n script/common/setup_gemini.sh` and `bash -n
  script/utils/agent-call` passed; `shellcheck` passed for the runner and
  regression test.
- `bash script/common/test_agent_call.sh` passed for synchronous success,
  provider failure, background completion, provider timeout, cancellation,
  and prompt-content exclusion from metadata.
- A real agy plan-mode tool refusal was normalized to
  `status=failed`, `exit_code=126`, and `reason=provider_denied_action`; it was
  not reported as a successful job.
- Codex-initiated agy smoke returned `CODEX_INITIATED_AGY_CHILD_OK` with
  `status=succeeded` and `exit_code=0`.
- agy-initiated Codex smoke returned `AGY_INITIATED_CODEX_OK`; its child job
  recorded `runtime=codex`, `status=succeeded`, and `exit_code=0`.
- The smoke calls used CLI processes only; no foreground UI or `orca terminal`
  was required. A nested Codex `read-only` attempt to launch a stateful runner
  was intentionally rejected by its sandbox (`Operation not permitted`), and
  no bypass flag was added.

## Notes

The first phase does not enable `--dangerously-skip-permissions`, global
`command(*)`, unrestricted URL access, or unrestricted MCP access. Runtime
settings are user-local but are managed from the dotfile source set. A
read-only job has no workspace mutation to roll back; cancellation terminates
the exact worker/provider PID and retains the metadata for inspection.
