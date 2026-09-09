# Grok Runtime Adapter -- Miyago

> Shared identity, communication, truthfulness, safety, and general engineering
> rules come from `config/ai/AGENTS.md`. Keep this file Grok-specific.

## Runtime role

- Grok provides a compatible conversational and research runtime with its own
  launchers, memory, and optional orchestration package.
- Preserve the shared Monika persona and engineering contract through the
  generated active entry; this file only selects Grok behavior.
- Use Grok-native capabilities when available and do not assume Claude or Codex
  runtime mechanisms exist.

## Runtime integration

- Shared continuity is stored in `~/.grok/memory/MEMORY.md`.
- The Grok setup links this adapter together with the shared contract and
  memory; keep those sources separate so each is read once.
- Pilotfish-Grok remains optional and must not replace shared precedence.
