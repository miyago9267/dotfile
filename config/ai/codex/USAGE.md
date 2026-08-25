# Codex Usage -- Miyago

## Daily entrypoints

- `cxf <prompt>`: fast second opinion / short review, maps to `codex exec --ignore-user-config -p fast`
- `cxc <prompt>` / `cxe <prompt>`: normal coding exec, maps to `codex exec --ignore-user-config -p code`
- `cxh <prompt>`: heavy exec, maps to `codex exec -p heavy`

Raw `codex` is intentionally untouched because `~/.codex/config.toml` carries desktop, project trust, MCP, and plugin state. Use `cxh` when that heavy surface is desired.

## Profile intent

- `fast`: shortest wall-clock; no base config, browser, document, spreadsheet, presentation, or computer-use plugins.
- `code`: normal coding; no base config and no heavy GUI/document plugins.
- `heavy`: inherits base config for browser/document-heavy or large tasks.

Warning: `heavy` uses `danger-full-access` with `approval_policy = "never"`. Use it only when the workspace is trusted and the task really needs the full heavy surface.

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

This checks that `fast` / `code` define no MCP servers, keep heavy plugins disabled, and parse under `--ignore-user-config --strict-config`.

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

Use `$i-have-adhd` to re-enable or reinforce the style after a session-level
pause. The local default still yields to Miyago's safety, verification, recap,
and plain-language preferences.
