---
name: prototype
description: "Codex throwaway prototype workflow -- build small disposable experiments to answer a concrete design, state, or UI question. Use when Miyago asks to prototype, sanity-check a model, try UI options, explore a state machine, or make something quick to play with before committing to production code."
user-invocable: true
when_to_use: "Use when learning from a runnable experiment is cheaper than designing the final implementation upfront."
tags: [codex, prototype, experiment, ui, state]
effort: medium
shell: preferred
runtime-scope: codex-native
---

# Codex Prototype

A prototype answers one question. Treat it as disposable from the first file.

## Pick The Prototype Type

- **Logic/state question**: build a tiny CLI or script that exercises the model
  and prints full state after each action.
- **UI question**: build a temporary route, page, or component with 2-4 distinct
  variants behind a simple switch.

State the question at the top of the prototype file or adjacent note.

## Rules

- Put prototype code near the relevant module or route, named with `prototype`,
  `scratch`, or equivalent local convention.
- Use the repo's existing runtime and routing conventions.
- Provide one command or URL to run it.
- Keep persistence in memory unless persistence itself is the question.
- Skip production polish, broad tests, and abstractions.
- Render or print enough state that Miyago can judge the result.
- Delete the prototype or fold the validated decision into production code when
  done.

## Verification

Run the cheapest command that proves the prototype starts and exercises the key
path. For UI prototypes, use Browser/Playwright only when Miyago asked for
browser verification or the UI behavior cannot be judged from code.

## Capture The Result

When the prototype answers its question, record the decision in the durable
place that matches the task:

- commit message
- issue/spec note
- ADR for hard-to-reverse architectural choices
- short `NOTES.md` next to the prototype if it must remain briefly
