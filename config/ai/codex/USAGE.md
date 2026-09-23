# Codex Usage -- Miyago

## Daily entrypoints

- `cxf <prompt>`: fast second opinion / short review, maps to
  `codex exec --ignore-user-config -p fast`
- `cxc <prompt>` / `cxe <prompt>`: normal coding exec, maps to
  `codex exec --ignore-user-config -p code`
- `cxh <prompt>`: heavy exec, maps to `codex exec -p heavy`

Raw `codex` keeps local desktop, project trust, MCP, and plugin state in each
`config.toml`. The version-controlled
[`model-defaults.toml`](model-defaults.toml) sets only the main-session model
and reasoning effort; `bash setup.sh` merges those two root-level values into
both native and Orca Codex homes, preserving the rest of each local config and
backing up a file before changing it. Use `cxh` when the heavy profile surface
is desired.

## Cross-runtime runner

For a bounded background read-only call to either runtime, use:

```bash
agent-call run --runtime agy --cwd /absolute/workspace \
  --prompt-file /absolute/prompt.txt --background
agent-call wait --job-dir /absolute/job-dir
```

把 `agy` 換成 `codex` 即可呼叫另一個 runtime。

The runner records structured metadata and provider stdout/stderr, enforces a
timeout, and never enables a permission or sandbox bypass. Keep write,
commit, push, credential, production, and other high-side-effect work on a
native gated session.

## Approval gate

`codex-approval-gate` is an independent opt-in wrapper around the local Codex
app-server. It keeps manual approval for high-risk requests and uses Touch ID
only for the allowlisted low-risk command policy.

Install the standalone tool from its own repository:

```bash
git clone https://github.com/miyago9267/codex-approval-gate ~/Project/Active/Tools/codex-approval-gate
cd ~/Project/Active/Tools/codex-approval-gate
./install.sh --dry-run
./install.sh --ref main
```

Run Codex through the gate:

```bash
~/.local/bin/codex-approval-gate
```

Use `CODEX_APPROVAL_AUTH=mock` only for local wiring tests. Normal `codex`,
`cxf`, `cxc`, and `cxh` entrypoints remain unchanged when the wrapper is not
used. The audit log is outside the repository at
`~/.local/state/codex-approval-gate/audit.jsonl`.

Rollback is immediate: stop the wrapper and invoke the normal Codex entrypoint
again. Remove the standalone tool with:

```bash
cd ~/Project/Active/Tools/codex-approval-gate
./install.sh --uninstall
```

## Profile intent

- `fast`: shortest wall-clock; no base config, browser, document, spreadsheet,
  presentation, or computer-use plugins.
- `code`: normal coding; no base config and no heavy GUI/document plugins.
- `heavy`: inherits base config for browser/document-heavy or large tasks.

Warning: `heavy` uses `danger-full-access` with
`approval_policy = "never"`. Use it only in trusted workspaces when the task
needs the full heavy surface.

## Benchmark

Run a small wall-clock benchmark:

```bash
bash ~/dotfile/script/utils/codex-bench.sh
```

Useful knobs:

- `CODEX_BENCH_RUNS=3` repeats each case.
- `CODEX_BENCH_PROMPT='...'` replaces the prompt.
- `CODEX_BENCH_OUT_DIR=/tmp/codex-bench` controls captured output.

## Hygiene check

Validate that light profiles stay clean:

```bash
bash ~/dotfile/script/utils/codex-profile-check.sh
```

This checks that `fast` / `code` define no MCP servers, keep heavy plugins
disabled, and parse under `--ignore-user-config --strict-config`.

## Focus output

The Codex adapter applies the local `focus-output` rules by default. They are
the canonical default response style for this runtime; the upstream
`i-have-adhd` plugin is optional and remains useful as a manual session toggle
or reinforcement.

The plugin is installed separately because Codex keeps marketplaces in
`~/.codex/config.toml` rather than in this repository.

Install or refresh it explicitly:

```bash
codex plugin marketplace add ayghri/i-have-adhd --ref main
codex plugin add i-have-adhd@i-have-adhd
```

Say `normal mode`, `詳細解說這一回合`, or `暫時詳細說明` for one detailed
response; the default style resumes automatically afterward. Use
`stop adhd mode` for a session-level pause, or `$i-have-adhd` to re-enable or
reinforce the style. The local default still yields to Miyago's safety,
verification, recap, and plain-language preferences.
