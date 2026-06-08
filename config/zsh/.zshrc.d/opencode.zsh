# OpenCode / oh-my-openagent
export OMO_SEND_ANONYMOUS_TELEMETRY=0
export OMO_DISABLE_POSTHOG=1

if [ -n "${AVANTE_OPENAI_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  export OPENAI_API_KEY="$AVANTE_OPENAI_API_KEY"
fi

if [ -n "${AVANTE_GEMINI_API_KEY:-}" ] && [ -z "${GEMINI_API_KEY:-}" ]; then
  export GEMINI_API_KEY="$AVANTE_GEMINI_API_KEY"
fi

opencode-secrets-sync() {
  local _dir="${OPENCODE_SECRET_DIR:-$HOME/.config/opencode/secrets}"
  [ -d "$HOME/.config/opencode" ] || return 0
  mkdir -p "$_dir" 2>/dev/null || return 0
  chmod 700 "$_dir" 2>/dev/null || true

  if [ -n "${GEMINI_API_KEY:-}" ] && { [ ! -s "$_dir/gemini-api-key" ] || grep -q '^replace-with-' "$_dir/gemini-api-key" 2>/dev/null; }; then
    printf '%s' "$GEMINI_API_KEY" > "$_dir/gemini-api-key"
    chmod 600 "$_dir/gemini-api-key" 2>/dev/null || true
  fi

  if [ -n "${ALUO_API_KEY:-${OPENCODE_ALUO_API_KEY:-}}" ] && { [ ! -s "$_dir/aluo-api-key" ] || grep -q '^replace-with-' "$_dir/aluo-api-key" 2>/dev/null; }; then
    printf '%s' "${ALUO_API_KEY:-$OPENCODE_ALUO_API_KEY}" > "$_dir/aluo-api-key"
    chmod 600 "$_dir/aluo-api-key" 2>/dev/null || true
  fi
}

opencode-secrets-sync

opencode-harness() {
  OPENCODE_CONFIG="${OPENCODE_CONFIG:-$HOME/.config/opencode-harness/opencode.json}" \
    OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode-harness}" \
    opencode "$@"
}

och() {
  opencode-harness "$@"
}

opencode-studio() {
  OPENCODE_CONFIG="$HOME/.config/opencode-studio/opencode.json" \
    OPENCODE_CONFIG_DIR="$HOME/.config/opencode-studio" \
    opencode "$@"
}

ocstudio() {
  opencode-studio "$@"
}

ulw() {
  opencode-harness run --agent "Sisyphus - ultraworker" --command ulw-loop "$@"
}

ultrawork() {
  ulw "$@"
}

oc54h() {
  opencode --model openai/gpt-5.4 --variant high "$@"
}

oc55() {
  opencode --model openai/gpt-5.5 "$@"
}

ocds() {
  opencode --model deepseek/deepseek-v4-flash "$@"
}

ocop() {
  opencode --model github-copilot/claude-opus-4.5 "$@"
}
