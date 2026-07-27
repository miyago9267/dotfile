# Install contract

## Required artifacts

`INSTALL.md` is an executable playbook for an AI agent, not a marketing README. It must state:

1. scope and prerequisites;
2. files and commands the agent must inspect before execution;
3. the exact confirmation boundary for writes, network access, credentials, and privileges;
4. the command to run, with a pinned `--ref` when releases exist;
5. post-install verification and expected signals;
6. rerun/update and uninstall behavior;
7. a concise final report listing changed paths and verification results.

`INSTALL_PROMPT.md` should be short enough to paste into an agent:

```text
Please install <project> for me. Fetch <raw INSTALL.md>, read it completely,
inspect the referenced installer before running it, ask for confirmation at the
documented boundary, then follow the playbook and report verification results.
```

`install.sh` is the human entrypoint. It should:

- work from both a checked-out repository and a raw URL;
- use `set -Eeuo pipefail`, a temporary directory, cleanup, and quoted paths;
- support `--help`, `--dry-run`, and a visible `--ref`/version choice;
- avoid `eval`, unbounded `rm`, implicit `sudo`, and silent writes outside the documented destination;
- shell-quote generated metadata and reject project names that would create path traversal or command substitution;
- delegate project-specific installation to a reviewable hook;
- be rerunnable without clobbering user configuration.

## Recommended layout

```text
INSTALL.md
INSTALL_PROMPT.md
install.sh
scripts/install-project.sh       # optional, project-specific hook
```

The generated installer uses `scripts/install-project.sh` when present. The hook receives the destination as its first argument and should document any additional arguments and side effects.

## Security review

Before declaring completion, inspect every command reachable from `install.sh`. Confirm URL/ref validation, archive or clone source, destination boundaries, permissions, backup behavior, and whether the installed runtime performs network access. Prefer a local dry run and static checks; do not claim a live install was verified when it was not.
