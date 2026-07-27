---
name: build-install
description: 建立跨專案可重用的雙模式安裝入口：給 AI agent 讀取並執行的 INSTALL.md playbook、給人類以 curl | bash 使用的 install.sh，以及可選的 copy-paste prompt。當使用者要新增、整理、重構或審查專案的安裝流程、bootstrap script、AI 安裝說明或 release 安裝入口時使用。
---

# Build Install

為目前專案建立一致、安全、可審查的安裝介面。核心要求是兩條路徑共用同一個實際 installer：

- AI path：`INSTALL.md` 只描述可驗證的步驟，並提供最小 prompt 讓 agent fetch、閱讀、確認後執行。
- Human path：`install.sh` 可由 `curl -fsSL URL | bash -s -- ...` 啟動，支援 release/ref pinning、dry-run 與明確錯誤。

## Workflow

1. Inspect the repository before editing. Identify the artifact to install, supported OS/shell, runtime prerequisites, destination, update/uninstall behavior, and any existing setup command. Never invent a destructive command or a required privilege.
2. Read [references/install-contract.md](references/install-contract.md). Use [scripts/scaffold_install.py](scripts/scaffold_install.py) to create missing `INSTALL.md`, `install.sh`, and `INSTALL_PROMPT.md`; preserve existing project-specific behavior when updating.
3. Replace every `TODO` and placeholder. Keep project-specific work in a local `scripts/install-project.sh` hook or an equivalent narrow command. Make the public installer a thin, auditable bootstrapper.
4. Write `INSTALL.md` as an agent playbook: preflight, files/commands to inspect, confirmation boundary, execution, verification, rollback/uninstall, and a report of what changed. Tell the agent to inspect `install.sh` before running it and to pin a release when possible.
5. Write `INSTALL_PROMPT.md` as a short copy-paste prompt that fetches the raw `INSTALL.md`, asks the agent to read and follow it, and does not bypass the confirmation boundary.
6. Make `install.sh` strict (`set -Eeuo pipefail`), quote variables, avoid `eval`, avoid implicit `sudo`, use a temporary directory with cleanup, and expose `--help`, `--dry-run`, `--ref`, and project-specific options only when implemented. Keep network access at install time; installed runtime code must not make unexpected network calls.
7. Verify with `bash -n install.sh`, a dry run, and the project’s narrowest relevant test. If available, run ShellCheck. Do not run a live install unless the user asks for it.

## Decision rules

- Prefer a tagged release or immutable commit over `main`; make the ref visible in output.
- Keep AI execution non-interactive unless the playbook explicitly needs user choices. Ask before writing credentials, changing shell startup files, modifying global settings, or using elevated privileges.
- Make reruns idempotent and preserve user configuration. Back up files before mutation and state the exact backup path.
- Do not put secrets, tokens, or unchecked remote command text in `INSTALL.md`.
- If an existing installer cannot meet these rules, document the risk and make the smallest compatible change rather than rewriting unrelated setup logic.

## Resources

- [install-contract.md](references/install-contract.md): output contract, security checklist, and verification matrix.
- [scaffold_install.py](scripts/scaffold_install.py): deterministic generator for the three public artifacts.
- `assets/`: source templates used by the generator; edit these when the reusable pattern changes.
