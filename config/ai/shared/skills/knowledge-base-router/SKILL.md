---
name: knowledge-base-router
description: Automatically route project, architecture, implementation, spec, incident, deployment, business-logic, and historical-decision questions to Miyago's local Obsidian knowledge bases. Use when a task names or occurs inside a known project, asks what was decided before or why, references specs, architecture, SOPs, infra, PMS, or RiceCall, requests a knowledge-base lookup or update, or when existing project knowledge could prevent rediscovery. Invoke proactively even when Miyago does not explicitly mention a knowledge base; follow the selected vault's local AGENTS.md for writes.
---

# Knowledge Base Router

Consult the relevant local vault before answering or changing a project when
existing decisions, specs, architecture, operations knowledge, or domain rules
could affect the work. Do not wait for Miyago to provide a vault path.

## Route the Task

| Need | Vault | Access |
| --- | --- | --- |
| Miyago-owned projects, specs, architecture, patterns, tools, workflows, and personal engineering decisions | `/Users/miyago/Project/Note/miyago-knowledge-base` | Read and write through its `AGENTS.md` |
| Service configuration, infrastructure, deployment, SOPs, incidents, and ADRs | `/Users/miyago/Project/Note/sre-knowledge-base` | Read and write through its `AGENTS.md` |
| PMS business logic, DB schema, and application-layer triage | `/Users/miyago/Project/Note/itrd-knowledge-base` | Read-only; never write |
| RiceCall product, architecture, operations, and project-specific knowledge | `/Users/miyago/Project/Note/ricecall-knowledge-base` | Read and write through its `AGENTS.md` |

Use more than one vault when the task crosses boundaries. Prefer the RiceCall
vault for RiceCall details; treat any node in another vault as a routing index,
not the canonical content.

## Identify the Project

1. Inspect the current working directory, Git root, repository name, remote, or
   path already supplied by the user.
2. For personal project work, open the Miyago vault `INDEX.md`, then locate the
   matching project node under `wiki/projects/`.
3. Route by the subject matter when no repository is present: infra to SRE,
   PMS domain questions to ITRD, and RiceCall work to its canonical vault.
4. Ask only when multiple plausible vaults would materially change the answer
   and local evidence cannot resolve the ambiguity.

## Query Workflow

1. Read the selected vault's `AGENTS.md` if it is not already loaded.
2. Read `INDEX.md` first when present; use its MOCs to select candidates.
3. Search narrowly with `rg` across titles, aliases, tags, frontmatter,
   wikilinks, `_MOC.md`, and relevant project nodes.
4. Read only the nodes needed for the current decision. Follow `## Related`
   links only when they resolve a concrete gap.
5. State which node supplied a decision or rule. Separate verified facts,
   inferences, conflicts, and missing knowledge.
6. If the vault has no relevant evidence, say so and continue from repository
   facts; do not invent a knowledge-base conclusion.

## Consult Proactively

Look up knowledge before implementation, diagnosis, planning, or review when
any of these apply:

- The current repo has a project node or recorded spec history.
- The request asks about prior decisions, architecture, conventions, trade-offs,
  incidents, deployment, business rules, or why something works this way.
- A completed or archived spec may already have promoted canonical knowledge.
- Re-discovering the answer from code would duplicate recorded project context.
- Infra, PMS, or RiceCall domain knowledge could change the safe next action.

Skip the vault lookup for trivial text edits, self-contained local facts, or
tasks whose answer cannot depend on stored project knowledge.

## Write Safely

Do not write merely because a query occurred. Write only when Miyago asks to
record or update knowledge, or when an authorized workflow explicitly includes
spec promotion or knowledge maintenance.

For an allowed write:

1. Follow the target vault's `AGENTS.md`, schema, templates, deduplication, MOC,
   index, and log rules.
2. Prefer updating an existing canonical node over creating a duplicate.
3. Use Obsidian wikilinks inside vaults.
4. Never write to `itrd-knowledge-base`.
5. Never store credentials, secrets, personal data, or unverified claims.
6. Run the target vault's lint command and report the result.

## Trigger Examples

- 「這個專案之前為什麼選這個架構？」
- 「幫我修 Monika 的 session 問題。」
- 「這個 service 怎麼部署？」
- 「PMS 這張表的業務規則是什麼？」
- 「把完成的 spec 整理進知識庫。」
