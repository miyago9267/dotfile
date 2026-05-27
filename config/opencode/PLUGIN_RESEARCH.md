# OpenCode Plugin Evaluation

## Install First

| Plugin | Purpose | Decision |
| --- | --- | --- |
| `opencode-snip` | Reduce shell output before it enters model context | Evaluate first |
| `Context Analysis` | Inspect token usage and context pressure | Evaluate first |
| `Dynamic Context Pruning` | Prune obsolete tool outputs | Evaluate after baseline |
| `Envsitter Guard` | Prevent `.env*` value leaks | Evaluate first |
| `Opencode Ignore` | Ignore noisy or sensitive paths | Evaluate first |

## Install Later

| Plugin | Purpose | Decision |
| --- | --- | --- |
| `Opencode Quota` | Provider quota and token tracking | Evaluate after token baseline |
| `opencode-mystatus` | Subscription quota visibility | Evaluate after auth compatibility check |
| `Handoff` | Focused continuation prompts | Evaluate only if handoff quality is weak |
| `OpenCode Agent Tmux` | Agent visibility in tmux | Evaluate after subagent flow is stable |

## Defer

| Plugin | Reason |
| --- | --- |
| `Micode` | Overlaps with `oh-my-openagent` orchestration |
| `Opencode Workspace` | Adds another multi-agent harness layer |
| Other mega-harness plugins | Too much prompt and behavior stacking before the slim layer is proven |

## Evaluation Rules

- Install one plugin at a time.
- Capture `opencode debug config` and `opencode stats` before and after.
- Prefer plugins that reduce context, expose quota, or protect secrets.
- Avoid plugins that add background agents or broad workflow systems before P0/P1/P2 are stable.
- Keep default `monika` skill tool disabled; test plugin prompt/tool impact with `monika-large` first.
- Keep `oh-my-openagent` out of the default `opencode` path; launch it through `opencode-harness`.

Sources:

- <https://opencode.ai/docs/plugins/>
- <https://github.com/awesome-opencode/awesome-opencode>
