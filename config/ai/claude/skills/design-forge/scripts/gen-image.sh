#!/usr/bin/env bash
# gen-image.sh -- generate a raster asset via OpenAI Images API (gpt-image-1).
# Usage: gen-image.sh "<prompt>" <out_path> [size]
#   size: 1024x1024 (default) | 1536x1024 | 1024x1536 | auto
# Exit codes: 0 ok (prints out_path) | 1 API error | 3 no OPENAI_API_KEY (caller falls back to Canva)
set -euo pipefail

PROMPT="${1:?prompt required}"
OUT="${2:?output path required}"
SIZE="${3:-1024x1024}"

[ -n "${OPENAI_API_KEY:-}" ] || { echo "OPENAI_API_KEY not set" >&2; exit 3; }

mkdir -p "$(dirname "$OUT")"

resp="$(curl -sS https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg p "$PROMPT" --arg s "$SIZE" \
        '{model:"gpt-image-1", prompt:$p, size:$s, n:1}')")"

b64="$(printf '%s' "$resp" | jq -r '.data[0].b64_json // empty')"
[ -n "$b64" ] || {
  echo "image-gen failed: $(printf '%s' "$resp" | jq -r '.error.message // .')" >&2
  exit 1
}

printf '%s' "$b64" | base64 --decode > "$OUT"
echo "$OUT"
