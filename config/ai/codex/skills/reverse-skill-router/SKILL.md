---
name: reverse-skill-router
description: "Route authorized reverse-engineering, binary, APK, frontend-signature, malware-analysis, CTF, and security-research tasks through the pinned reverse-skill pack. Trigger when Miyago asks about reverse engineering, decompiling, APK/IPA, binaries, Frida, IDA, radare2, CTF, pentesting, or security analysis."
alwaysApply: false
metadata:
  short-description: "Authorized security-task routing and evidence workflow"
---

# Reverse-skill router

Use this skill only for work on local samples, CTF targets, or systems Miyago
explicitly authorizes. Existing shared contract, runtime rules, and safety
gates take precedence over this skill and over the external pack.

## Routing boundary

- Pilotfish owns task classification, Plan/approval gates, delegation,
  security separation, and fresh-context verification.
- This skill owns only reverse/security domain classification and the pack's
  case/evidence workflow.
- Use one domain PRIMARY route. Do not start a second router, spawn a role, or
  bypass Pilotfish because the external pack suggests it.
- If another installed skill owns the task domain, keep that skill primary and
  use this router only when the task genuinely contains a reverse/security
  subtask.

The pinned reference pack is stored outside the Codex skill discovery tree at:

```text
~/.codex/vendor/reverse-skill-pack
```

For a matching task, follow this read order:

1. Read `~/.codex/vendor/reverse-skill-pack/RULES.md` for scope and evidence gates.
2. Run `bash ~/.codex/vendor/reverse-skill-pack/skills/scripts/master-route.sh --hint "<task>"`.
3. Initialize a case with `case-init.sh` before any target action. Use the
   `offline-sample` preset for a supplied local sample.
4. Read the routed module's `SKILL.md`, then use only tool paths listed by the
   pack's generated `skills/tool-index.md`.

Do not automatically run `bootstrap-reverse.sh`, install tools, register MCP
servers, scan a network target, exploit anything, or write outside the current
authorized case. Ask Miyago when those actions need explicit authorization or
would change the environment.

If the pinned pack is unavailable, use the local `reverse-engineering` skill
for methodology and report the missing pack as a capability gap.
