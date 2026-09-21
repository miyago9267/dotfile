# Grok CLI UX Reverse Report

## Scope verdict

The authorized offline sample `/Users/miyago/.local/bin/grok` was inspected for
interaction and rendering seams only. No exploitation, network access, source
reconstruction, or mutation of the sample occurred.

## Findings

1. `xai-grok-pager` is the product boundary. The binary contains dedicated
   modules for input, interaction routing, queueing, dashboard, prompt widgets,
   scrollback blocks, plan approval, mouse handling, and Mermaid content.
2. Dashboard and tasks are first-class pager surfaces. The help surface exposes
   session supervision, `Ctrl+B` backgrounding, and `Ctrl+G` task inspection.
3. Terminal integration is an explicit feature area. `doctor`, `wrap`, mouse
   reporting, OSC 52, native terminal capability checks, and media/audio-linked
   frameworks are visible in the executable surface.
4. Rich content is block-oriented. Embedded anchors for tool grouping,
   text selection, prompt image chips, Markdown blocks, and Mermaid rendering
   explain why the reference feels like an IDE pager instead of a chat transcript.

## Applied design decisions

`lumen` adopts the smallest independently useful slice of those seams:

- `Ctrl+\\` / `/dashboard` supervises real Codex top-level threads.
- idle `Enter` sends, busy `Enter` queues, and Kitty/xterm `Ctrl+Enter` performs
  cancel-and-send.
- prompt editing supports visual line movement, history, cursor placement, and
  SGR mouse clicks.
- transcript cards, collapsed tool drawers, hover footer detail, Markdown, a
  deterministic Mermaid preview, and turn recap are rendered in one pager.

## Deferred parity

Independent aside turns (`/btw`), dashboard permission routing, background task
pane, plan code-review controls, `doctor` / `wrap`, workflow dashboard,
worktree fork, media chips, and voice input remain explicit follow-up work.
