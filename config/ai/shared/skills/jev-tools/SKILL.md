---
name: jev-tools
description: Use the shared Jev browser and Reticle adapters when browser automation or runtime verification is explicitly needed.
---

# Jev tools

Use these only when the task needs browser action selection or verification of an app
that Miyago owns.

- Browser automation: use `jev-browser` for one observable goal at a time.
- Runtime verification: use Reticle only for a local development app after its project
  SDK has been initialized.
- Treat `likely_done`, `ambiguous`, `needs_confirmation`, `stuck`, `blocked`, and
  `unknown` as non-success states.
- Never pass secrets as command arguments. `TYPESAFE_API_KEY` must come from the
  protected runtime environment.
- Do not use fast Jev compaction to delete context yet; the current integration is
  shadow/dry-run only.

Runtime-specific commands are documented in:

`config/ai/shared/jev/pi-jev-tools.md`
