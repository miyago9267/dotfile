---
name: jev-tools
description: Use Jev browser, Reticle, TypeSafe judgments, or Jev tooling installation when explicitly needed.
---

# Jev tools

Use Jev only for a bounded judgment, one browser goal, verification of an app Miyago
owns, or an explicitly requested Jev installation/configuration task.

- Browser automation: use `jev-browser` for one observable goal at a time.
- Runtime verification: use Reticle only for a local development app after its project
  SDK has been initialized.
- For installation, credentials, runtime mapping, synthetic checks,
  disablement, or rollback, read [the install guide](../../jev/INSTALL.md) before
  changing a runtime.
- For structured decisions, use TypeSafe Choice for one mutually exclusive outcome,
  Noul for independent yes/no judgments, and Score for an ordered rubric. Keep the
  resulting action in deterministic code; confidence is not proof of correctness.
- Treat `likely_done`, `ambiguous`, `needs_confirmation`, `stuck`, `blocked`, and
  `unknown` as non-success states.
- Never pass secrets as command arguments. `TYPESAFE_API_KEY` must come from the
  protected runtime environment.
- Do not use `fast-jev-compaction` to delete context. Internal hooks are shadow-only.
  The separate Codex checkpoint plugin supplements native compaction and must be
  installed and enabled explicitly.

Runtime-specific commands are documented in:

`config/ai/shared/jev/pi-jev-tools.md`
