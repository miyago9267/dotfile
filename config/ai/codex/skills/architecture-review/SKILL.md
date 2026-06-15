---
name: architecture-review
description: "Codex architecture review vocabulary and workflow -- find deep-module and testability opportunities without broad rewrites. Use when Miyago asks about architecture, refactoring opportunities, codebase design, coupling, seams, module boundaries, or making code easier to test/navigate."
user-invocable: true
when_to_use: "Use for read-only architecture assessment or for planning a focused refactor before implementation."
tags: [codex, architecture, refactor, design, testability]
effort: medium
shell: preferred
runtime-scope: codex-native
---

# Codex Architecture Review

Look for architectural friction that affects locality, leverage, and
testability. Do not refactor while reviewing unless Miyago explicitly asks.

## Vocabulary

- **Module**: anything with an interface and implementation: function, class,
  package, route, feature slice.
- **Interface**: everything a caller must know: types, invariants, error modes,
  order, config, performance expectations.
- **Implementation**: code hidden behind the interface.
- **Seam**: where behavior can vary without editing the caller.
- **Adapter**: a concrete implementation at a seam.
- **Depth**: how much useful behavior sits behind a small interface.
- **Locality**: changes and bugs concentrate in one place.
- **Leverage**: one module implementation benefits many callers or tests.

## Review Flow

1. Read relevant `CONTEXT.md`, `CONTEXT-MAP.md`, and `docs/adr/` if present.
   Proceed silently if absent.
2. Inspect only the modules related to the requested area.
3. Identify friction:
   - understanding one concept requires bouncing across many shallow files
   - callers must know implementation details
   - tests bypass the public interface
   - extracted helpers hide no complexity
   - one seam has only one adapter and no real variation
   - changes require coordinated edits in many callers
4. Apply the deletion test: if deleting a module removes complexity, it is
   likely pass-through; if complexity spreads into callers, it was earning its
   keep.
5. Present candidates with file references, risk, expected benefit, and a
   recommended first move.

## Output Shape

Lead with findings, ordered by impact:

- Problem
- Evidence
- Suggested change
- Why it improves locality, leverage, or testability
- Verification strategy

Mark each recommendation as `Strong`, `Worth exploring`, or `Speculative`.

## Boundaries

- Do not propose architecture work that contradicts an ADR without saying so.
- Do not invent abstractions for hypothetical future cases.
- Do not create broad specs unless the selected refactor is large or
  cross-module.
- Prefer one focused refactor that creates a better test seam over sweeping
  cleanup.
