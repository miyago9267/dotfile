---
name: user-profile
description: Stack, working style, environment preferences -- all projects
type: user
---

## Environment

- macOS (primary) + WSL Ubuntu + Windows. Editor: Neovim.
- Claude Max subscription (not API billing); architecture designs should route through claude-agent-sdk to spend subscription quota.

## Stack

- Primary: TypeScript, Bun, Vue 3, Hono, Go. Go is first-class — recommend Go tooling with equal priority.
- Frontend: Nuxt 4, Vue 3. Deploy: Docker, GitHub Actions self-hosted runner, SSH. DB: MongoDB, ChromaDB (vector search).

## Working Style

- Bursty productivity: intense periods, pauses, then returns.
- SDD (spec-driven) + TDD workflow.
- Aggressive context compression; /compact habit formed (70%).
- Commits: no Co-Authored-By or any AI attribution. Comments: method/interface level and above only, never inline.

## Cares About

- AI persona continuity — memory must persist, persona must not drift.
- Self-bootstrapping — agents should improve themselves.
- Pragmatism — no over-engineering; working beats perfect.
