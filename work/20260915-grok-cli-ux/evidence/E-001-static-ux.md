# E-001 Static UX Surface Map

## Target

- asset: `/Users/miyago/.local/bin/grok`
- type: Mach-O 64-bit executable arm64
- sha256: `3323b3c1c8719d73a5a6a6e707276a0d36bd0cefc6b4b799eeba4bf87825b710`
- analysis mode: local static inspection, offline

## Collection

The following read-only commands were used against the in-scope executable:

```text
file /Users/miyago/.local/bin/grok
shasum -a 256 /Users/miyago/.local/bin/grok
grok --help
strings -a /Users/miyago/.local/bin/grok
otool -L /Users/miyago/.local/bin/grok
```

## Observed anchors

- CLI surface includes `dashboard`, `doctor`, `wrap`, `sessions`, `workflow`, `--minimal`,
  `--no-alt-screen`, `--worktree`, `--fork-session`, agent controls, approval and
  sandbox controls.
- Embedded module paths identify `xai-grok-pager` seams for
  `app/agent_view/input.rs`, `interactions.rs`, `queue.rs`, `render.rs`,
  `app/dashboard`, `views/plan_approval_view.rs`, `views/prompt_widget/mod.rs`,
  `scrollback/text_selection.rs`, and `scrollback/blocks/mermaid_content.rs`.
- Embedded help and event strings identify `Ctrl+B` foreground backgrounding,
  `Ctrl+G` tasks pane, mouse reporting, grouped tool output, prompt image chips,
  Mermaid rendering, terminal doctor checks, and OSC 52 clipboard wrapping.
- Linked frameworks include AppKit, CoreGraphics, IOKit, AudioUnit and CoreAudio,
  consistent with the advertised native terminal/media integration surface.

## Interpretation

The strongest reusable design seam is a pager-level interaction model: the same
viewport owns transcript rendering, prompt editing, session supervision, task
status, and terminal capability feedback. Queue, cancel-and-send, aside, and
background work are separate state transitions rather than alternate labels for
one chat send action.

This evidence informed the `lumen` vertical slice: terminal-native prompt
editing, conversation cards, collapsed tool drawers, hover detail, compact recap,
and a real `thread/list` / `thread/resume` dashboard path. No Grok source,
binary patch, or brand asset was copied.

## Limits

Static strings expose names and seams, not complete runtime semantics. The
behavior list supplied in the task is treated as product reference material; it
was not independently re-executed against remote services. The remaining
parity items are recorded in the standalone repo spec.
