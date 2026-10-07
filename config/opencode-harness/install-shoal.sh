#!/usr/bin/env bash
set -euo pipefail

# SHOAL_ROOT 指向 shoal repo 根目錄。
source_repo="${SHOAL_ROOT:-$HOME/Project/Active/Forks/Fork-Remaster-code/shoal}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_file="$script_dir/plugins/shoal-opencode.js"

if ! git -C "$source_repo" rev-parse --verify HEAD >/dev/null 2>&1; then
  printf 'shoal repository not found: %s\n' "$source_repo" >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  printf 'bun is required to build shoal-opencode\n' >&2
  exit 1
fi

# 從 HEAD 取 hosts/opencode 到暫存目錄再 build，不吃未 commit 的 WIP，也不在 repo 內留下 node_modules / dist。
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
git -C "$source_repo" archive HEAD hosts/opencode | tar -x -C "$tmp_dir"

# 打成單一 bundle：tsc 的輸出會 import ../route-resolution.js 等相對路徑，
# 單獨放進 plugins/ 會載入失敗。參數與 shoal 的 install.sh 相同。
(
  cd "$tmp_dir/hosts/opencode/plugin"
  bun install --frozen-lockfile >/dev/null
  bun build src/plugin/shoal-opencode.ts --bundle --format esm --target bun \
    --outfile "$tmp_dir/shoal-opencode.js" >/dev/null
)

install -m 0644 "$tmp_dir/shoal-opencode.js" "$target_file"
printf 'installed %s\n' "$target_file"
