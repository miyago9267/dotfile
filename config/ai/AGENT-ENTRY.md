# Canonical AI Configuration Source

```yaml
source_root: /Users/miyago/dotfile/config/ai
source_policy: hard
activation: symlinked-or-deployed-to-runtime-locations
workspace_root: /Users/miyago/Project/AI/agent-workspace
workspace_role: canonical-global-rule-base
project_ai_monika: non-entry
```

## Hard boundary

`/Users/miyago/dotfile/config/ai/` is the only canonical source set for
Miyago's Agent behavior, routing, shared rules, skills, memories and runtime
adapters. Its files take effect through the runtime locations they are linked
or deployed to; this source directory is not itself a shared project runtime.

Global Agent experience, task context, system maps and handoffs must be read
from `/Users/miyago/Project/AI/agent-workspace/`. This is the canonical global
rule base and its first version is document-only.

`/Users/miyago/Project/AI/monika` is explicitly `non-entry`. Do not read it,
modify it, test it, or infer global Agent behavior from it unless Miyago gives a
project-specific task that names that path.

When the task concerns global Agent behavior and the entry set does not contain
enough information, stop and report the missing entry data. Do not fall back to
any project checkout.

There is no fallback workspace. Do not substitute another project directory by
name similarity, recency or current working directory.
