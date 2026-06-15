# Codex Coralline

This is a Codex-oriented adapter of `coralline`.

Codex currently has no verified `statusLine` config key like Claude Code's `statusLine`.
For that reason this directory is managed as a renderer and config bundle, without adding an
unknown key to `*.config.toml`.

## Smoke Test

```bash
printf '{"cwd":"%s","model":"gpt-5.5","duration_ms":123000}\n' "$PWD" \
  | CORALLINE_CONFIG=~/dotfile/config/ai/codex/coralline.conf \
    bash ~/dotfile/config/ai/codex/coralline/statusline.sh
```

`script/common/setup_codex.sh` links this directory to `~/.codex/coralline` and links
`coralline.conf` to `~/.codex/coralline.conf`.
