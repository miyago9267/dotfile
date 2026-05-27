# OpenCode / oh-my-openagent
export OMO_SEND_ANONYMOUS_TELEMETRY=0
export OMO_DISABLE_POSTHOG=1

if [ -n "${AVANTE_OPENAI_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  export OPENAI_API_KEY="$AVANTE_OPENAI_API_KEY"
fi

if [ -n "${AVANTE_GEMINI_API_KEY:-}" ] && [ -z "${GEMINI_API_KEY:-}" ]; then
  export GEMINI_API_KEY="$AVANTE_GEMINI_API_KEY"
fi

opencode-harness() {
  OPENCODE_CONFIG="${OPENCODE_CONFIG:-$HOME/.config/opencode-harness/opencode.json}" \
    OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode-harness}" \
    opencode "$@"
}

och() {
  opencode-harness "$@"
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
