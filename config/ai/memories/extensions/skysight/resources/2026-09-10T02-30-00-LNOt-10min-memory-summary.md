---
title: Pilotfish Astra Routing Review
description: You focused Orca on pilotfish-codex work around an opt-in Astra budget/routing profile. You briefly checked a credential manager in Dia, then returned to Orca to inspect routing specs, templates, and tests.
applications: [com.stablyai.orca, company.thebrowser.dia]
---

## Memory summary

The user spent the recorded activity in Orca, continuing the `pilotfish-codex` thread that was already active before this window. The visible work centered on `agent-benchmark-waza` and an opt-in Astra thinking/main-session budget profile that would preserve Luna/Sol as the default routing path. The user also briefly switched to Dia with KeeWeb open and selected a hidden credential value, but no credential detail is retained.

No explicit code edit, commit, or test result was visible in this window. The segment recorded events only through about 02:30:53Z, despite the summary window ending at 02:40:00Z.

### Relevant prior context

The immediately preceding 02:20 summary established that `pilotfish-codex` had shifted into post-`v1.8.0-rc.2` follow-up work. That prior window showed route/spec/status checks around cost-controlled next steps, with Astra usage, reasoning strength, session usage, and token cost under consideration.

The same prior summary also showed VM Migration and GCP/KeeWeb work as nearby but secondary context. VM Migration had identified `develop` Native MySQL as a shared database host, with `pms` dominating observed schema-level disk usage and remaining uncertainty around physical MySQL storage overhead.

### Important non-obvious context about the user

- `com.stablyai.orca`: the active workspace and agent hub for `pilotfish-codex`, VM Migration, and other concurrent work cards.
- `company.thebrowser.dia`: used for KeeWeb/credential lookup during the window.
- `pilotfish-codex`: active thread involved Astra routing/profile design after `v1.8.0-rc.2`.
- `agent-benchmark-waza`: visible Context Harness task name for the Astra budget/routing profile work.
- `docs/plans/astra-plan-v2.md`: active planning file being searched for headings and terms such as Astra, usage, budget, prompt, profile, mode, and opt-in behavior.
- `install/routing_contract.py`, `install/benchmark_routing.py`, `hooks/pilotfish_autoroute_gate.py`: active implementation files being inspected for routing behavior.
- `templates/config.snippet.toml`, `templates/agents/*.toml`: active template/config files being inspected.
- `tests/test_astra_routing.py`, `tests/test_templates.py`: active test files being inspected, with no visible pass/fail result in this segment.

## Recording summary

- The window opened in Orca with the `pilotfish-codex` row working on a `miyago-context-harness plan --task agent-benchmark-waza` command. The visible summary described designing an opt-in Astra thinking/main-session budget profile while preserving default Luna/Sol routing.
- Orca showed many concurrent workspace cards and terminal sessions, including `VM-Migration`, `ikalatv-2` billing-spike analysis, VPN/RMS CI work, and `pilotfish-codex`; the active focus returned to `pilotfish-codex`.
- The user briefly switched to Dia where KeeWeb was open. The visible page showed credential-manager categories and MySQL-related entries; a hidden credential value was selected. Specific credential values, usernames, hosts, and page content are omitted.
- Back in Orca, visible commands inspected project structure and routing-related files:
  - `rg --files | sort | sed -n '1,240p'`
  - `sed` reads of `docs/specs/usage-first-routing/SPEC.md`, `docs/specs/model-routing-tuning/SPEC.md`, and a role-fitness benchmark spec path truncated in the capture.
  - `sed` reads of `install/routing_contract.py`, `install/benchmark_routing.py`, and `hooks/pilotfish_autoroute_gate.py`.
  - `sed` reads of `templates/config.snippet.toml` and `templates/agents/*.toml`.
  - `rg` search in `docs/plans/astra-plan-v2.md` for terms related to defaults, main session, Astra, cost, usage, budget, prompts, profiles, modes, and opt-in behavior.
  - `sed` reads of `install/AGENT-INSTALL.md`, `docs/plans/astra-plan-v2.md`, `tests/test_astra_routing.py`, and `tests/test_templates.py`.
- The user typed a short Chinese thought in Orca terminal input about records being washed out/overwritten; it appeared to be contextual commentary, not a durable requirement.
- The final visible Orca state showed `pilotfish-codex` still working and tabs such as `調整 plan-verifier 優先順序`, `GPT 6 Astra 優勢分析`, and `Terminal 3`.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-10T02-30-00Z/events.jsonl
- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-10T02-30-00Z/metadata.json
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T02-20-00-EzxV-10min-memory-summary.md