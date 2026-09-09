---
name: ask-tty
description: "Handle shell commands that need one-line user input in Codex without Claude-specific stdin bridges."
metadata:
  short-description: "Codex-native interactive command input"
  when_to_use: "Use when a local command genuinely needs a short non-secret response, a confirmation, or visible terminal interaction."
  tags: [codex, stdin, interactive, tty, input]
  effort: low
  shell: preferred
  runtime-scope: codex-native
---

# Codex ask-tty

Use Codex's native user-input flow for short, non-secret responses. Do not use
Claude-specific `tty:` prefixes, `tty-respond` hooks, file polling, or a
background process waiting for a response.

## Decision order

1. Remove the prompt with a non-interactive flag when the command supports it.
2. For a short, non-secret value or confirmation, use the native user-input
   tool, then run the command with that value on stdin.
3. For passwords, tokens, passphrases, or other credentials, use
   `~/bin/agent-secret`; never request or echo the secret in chat or logs.
4. For a TUI or a command that requires a real terminal, use a visible terminal
   session. Do not fake a TTY with a file-backed response channel.

## Execution constraints

- Keep the input single-purpose and bounded to the command being run.
- Do not place secret values in command arguments, environment snapshots,
  temporary files, or captured output.
- Prefer `stdin` piping for ordinary values; quote user input safely.
- If the command can be made non-interactive, use that form instead of asking.
- If the input channel is unavailable, stop and report the exact command and
  missing interaction; do not poll indefinitely.

## Boundary

This skill only supplies Codex-side input handling. It does not provide
permissions, credential storage, SSH automation, or a general background job
runner.
