// OpenCode file-based secrets template.
//
// Fresh machine setup:
//   bash script/common/install_opencode.sh
//   $EDITOR ~/.config/opencode/secrets/gemini-api-key
//   $EDITOR ~/.config/opencode/secrets/aluo-api-key
//   $EDITOR ~/.config/opencode/secrets/chatgpt-proxy-base-url
//   $EDITOR ~/.config/opencode/secrets/grok-cli-base-url
//
// The real files live in ~/.config/opencode/secrets/ and are ignored by git.
// Keep each file to the raw secret value only, with no quotes or YAML syntax.
// Base URL files should include the full OpenAI-compatible /v1 endpoint.
