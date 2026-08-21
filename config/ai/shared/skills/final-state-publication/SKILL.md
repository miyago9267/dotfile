---
name: final-state-publication
description: Generate PRs, comments, summaries, checkpoints, and memory entries from the currently accepted final state instead of conversational correction history. Use when a durable artifact will be written or published; do not use for ordinary direct replies.
metadata:
  short-description: Publish final state without transcript residue
---

# Final-State Publication

Use this skill when turning an interactive task into a durable artifact. The
artifact must describe the accepted current state, not the path taken to reach
it.

## Source boundary

Treat the conversation as execution context. It may contain guesses, rejected
interpretations, abandoned edits, and self-corrections. It is not a publication
source.

Build the artifact from the narrowest available set of authoritative inputs:

1. the currently accepted task intent and acceptance criteria;
2. current source and the final diff;
3. direct validation evidence;
4. repository or destination-specific templates.

If those inputs do not establish a claim, mark it `unverified` or omit it. Do
not recover the claim from conversational history merely because it appeared
there earlier.

## State normalization

When a user correction changes the requested outcome, replace the affected
field in the working state. Do not promote the correction into a new
requirement or preserve the rejected interpretation in the final description.

Describe the result positively and independently. A removed or rejected item
belongs in the artifact only when its absence is an independent acceptance,
safety, compatibility, legal, or domain constraint. Otherwise it is iteration
residue.

## Publication rules

- State what the change does now.
- Include only rationale that affects maintenance, operation, review, or
  acceptance and cannot be recovered from the diff.
- Omit prior attempts, correction steps, abandoned approaches, removed content,
  and explanations of what the work is not.
- Do not invent a fixed section set. Use the destination template and the
  smallest structure that communicates the final result.
- Keep routine process narration out of PRs, comments, summaries, and memory.

Before publishing, apply this test:

> Could a reader understand and review this artifact without seeing the
> conversation?

If no, replace historical narration with the current accepted state, or mark
the missing fact as unknown. For every negative statement, verify that it is a
durable constraint rather than evidence of a previous correction.

## Context isolation

When possible, use a fresh publication context containing only the authoritative
inputs above. Do not paste the full transcript into a PR or summary writer.
When a fresh context is unavailable, mentally apply the same boundary and
discard transcript-only material before drafting.
