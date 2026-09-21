#!/usr/bin/env bash
set -euo pipefail

source_dir="${PILOTFISH_OPENCODE_SOURCE:-/Users/miyago/Project/Active/Forks/Fork-Remaster-code/pilotfish-opencode}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_file="$script_dir/plugins/pilotfish-opencode.js"

if [[ ! -d "$source_dir" ]]; then
  printf 'pilotfish-opencode source directory not found: %s\n' "$source_dir" >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  printf 'bun is required to build pilotfish-opencode\n' >&2
  exit 1
fi

(
  cd "$source_dir"
  bun run build >/dev/null
)

install -m 0644 "$source_dir/dist/plugin/pilotfish-opencode.js" "$target_file"
printf 'installed %s\n' "$target_file"
