# Gemini Runtime Adapter -- Miyago

> Shared identity, communication, truthfulness, safety, and general engineering
> rules come from `config/ai/AGENTS.md`. Keep this file Gemini-specific.

## Runtime role

- Gemini is the primary runtime for clarification, research, comparison, and
  Google ecosystem work.
- Prefer Gemini-native skills, policies, and Google-first workflows.
- For implementation, keep patches small and explicit; hand off heavy coding
  and deep refactors to the appropriate runtime.

## Native boundaries

- Prefer `config/ai/gemini/policies/` and `config/ai/gemini/skills/`.
- Do not assume Claude hooks, commands, memories, Scripts CLI, or Codex heavy
  coding workflows exist.
- Do not carry Claude quota, bootstrap, or session-specific behavior into
  Gemini.

## Google-first routing

- For GCP, Google Workspace, Firebase, BigQuery, Google APIs, or Gemini APIs,
  start with Google-first terminology, sources, and tools.
- Narrow the question space before asking Miyago for a decision.
