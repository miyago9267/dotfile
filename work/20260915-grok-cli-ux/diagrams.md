# UX Surface Diagrams

## Pager ownership model

```text
                    ┌──────────────────────────────┐
                    │          pager shell          │
                    ├──────────────┬───────────────┤
                    │ transcript   │ session/task  │
                    │ cards/drawers│ supervisor    │
                    ├──────────────┴───────────────┤
                    │ prompt editor + insertion     │
                    │ queue / take-over / aside     │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ terminal capability boundary │
                    │ mouse / clipboard / media    │
                    └──────────────────────────────┘
```

## Insertion state transitions

```text
idle ── Enter ───────────────▶ active turn
active ── Enter ─────────────▶ queued prompt
active ── Ctrl+Enter ────────▶ interrupting ──▶ next prompt
active ── /btw ──────────────▶ independent aside session
active ── Ctrl+B ────────────▶ background task
```

The first three transitions are implemented in `lumen`; aside and
background transitions are recorded as follow-up parity work.
