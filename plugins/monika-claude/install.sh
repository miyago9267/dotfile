#!/bin/bash
set -euo pipefail

# dev-discipline installer
# Claude Code: use /install-plugin from GitHub repo (recommended)
# Other tools: bash install.sh [--tool auto|claude,codex,...] [--project [dir]]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.0.0"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

usage() {
  cat <<EOF
dev-discipline installer v${VERSION}

Usage:
  bash install.sh                          Interactive mode
  bash install.sh --tool auto              Auto-detect and install for all AI tools
  bash install.sh --tool claude,codex      Install for specific tools only
  bash install.sh --project [dir]          Set up AGENTS.md + SDD v2 structure in a project
  bash install.sh --export                 Print AGENTS.md to stdout

Claude Code users:
  Recommended: /install-plugin from the GitHub repo
  This script is for non-Claude tools or manual Claude setup.

Components installed (Claude):
  15 skills    SDD/TDD/efficiency/code-review/safe-ops/...
  8 agents     code-reviewer/debugger/researcher/planner/...
  17 commands   /sdd /handoff /pickup /verify /plan /learn ...
  2 hooks      auto-format + markdown-lint
  2 rules      sdd-tdd + reverse-engineering
  10 scripts   bootstrap/check/log/lesson/snapshot/end-session/...
  5 templates  SPEC/TASKS/TESTS/PROGRESS/AGENTS.md

EOF
  exit 0
}

# =============================================================================
# Tool detection
# =============================================================================

detect_claude()  { [[ -d "${HOME}/.claude" ]] || command -v claude &>/dev/null; }
detect_codex()   { [[ -d "${HOME}/.codex" ]]  || command -v codex &>/dev/null; }
detect_gemini()  { [[ -d "${HOME}/.gemini" ]] || command -v gemini &>/dev/null; }
detect_cursor()  { [[ -d "${HOME}/.cursor" ]] || [[ -d "${HOME}/Library/Application Support/Cursor" ]]; }
detect_copilot() { command -v gh &>/dev/null && gh extension list 2>/dev/null | grep -q copilot; }

detect_all() {
  local found=()
  detect_claude  && found+=(claude)
  detect_codex   && found+=(codex)
  detect_gemini  && found+=(gemini)
  detect_cursor  && found+=(cursor)
  detect_copilot && found+=(copilot)
  echo "${found[*]}"
}

# =============================================================================
# AGENTS.md shim
# =============================================================================

AGENTS_SHIM='## AGENTS.md

進入任何專案時，若根目錄存在 `AGENTS.md` 檔案，必須將其內容視為本專案的最高開發準則。
請在開始任何任務前先讀取 `AGENTS.md` 並嚴格遵守其中所有規則。'

inject_shim() {
  local file="$1"
  if [[ -f "$file" ]] && grep -q "AGENTS.md" "$file" 2>/dev/null; then
    info "$(basename "$file") already has AGENTS.md reference, skip"
    return
  fi
  if [[ -f "$file" ]]; then
    echo "" >> "$file"
    echo "${AGENTS_SHIM}" >> "$file"
  else
    echo "${AGENTS_SHIM}" > "$file"
  fi
}

# =============================================================================
# Claude install
# =============================================================================

install_claude() {
  local target="${HOME}/.claude"
  mkdir -p "${target}/commands" "${target}/agents" "${target}/rules" "${target}/templates" "${target}/scripts"

  # Skills
  for skill_dir in "${SCRIPT_DIR}"/skills/*/; do
    local skill_name
    skill_name=$(basename "$skill_dir")
    mkdir -p "${target}/skills/${skill_name}"
    cp "${skill_dir}"SKILL.md "${target}/skills/${skill_name}/SKILL.md"
    # Copy companion scripts (e.g., suggest-compact.sh)
    for script_file in "${skill_dir}"*.sh; do
      [[ -f "$script_file" ]] && cp "$script_file" "${target}/skills/${skill_name}/" && chmod +x "${target}/skills/${skill_name}/$(basename "$script_file")"
    done
  done

  # Agents
  for agent_file in "${SCRIPT_DIR}"/agents/*.md; do
    [[ -f "$agent_file" ]] && cp "$agent_file" "${target}/agents/"
  done

  # Commands
  for cmd_file in "${SCRIPT_DIR}"/commands/*.md; do
    [[ -f "$cmd_file" ]] && cp "$cmd_file" "${target}/commands/"
  done

  # Rules
  for rule_file in "${SCRIPT_DIR}"/rules/*.md; do
    [[ -f "$rule_file" ]] && cp "$rule_file" "${target}/rules/"
  done

  # Scripts
  for script_file in "${SCRIPT_DIR}"/scripts/*.sh; do
    [[ -f "$script_file" ]] && cp "$script_file" "${target}/scripts/" && chmod +x "${target}/scripts/$(basename "$script_file")"
  done

  # Templates
  for tmpl_file in "${SCRIPT_DIR}"/templates/*; do
    [[ -f "$tmpl_file" ]] && cp "$tmpl_file" "${target}/templates/"
  done

  # Markdownlint config
  if [[ -f "${SCRIPT_DIR}/config/markdownlint.json" && ! -f "${HOME}/.markdownlint.json" ]]; then
    cp "${SCRIPT_DIR}/config/markdownlint.json" "${HOME}/.markdownlint.json"
    ok "~/.markdownlint.json created"
  fi

  # AGENTS.md shim
  inject_shim "${target}/CLAUDE.md"

  ok "Claude: skills, agents, commands, rules, scripts, templates, hooks"
}

# =============================================================================
# Other tool installs
# =============================================================================

install_codex() {
  local target="${HOME}/.codex"
  mkdir -p "${target}"
  inject_shim "${target}/AGENTS.md"
  ok "Codex: AGENTS.md shim (native support)"
}

install_gemini() {
  local target="${HOME}/.gemini"
  mkdir -p "${target}"
  inject_shim "${target}/GEMINI.md"
  ok "Gemini: GEMINI.md shim"
}

install_cursor() {
  ok "Cursor: native AGENTS.md support, no extra config needed"
}

install_copilot() {
  local target="${HOME}/.copilot"
  mkdir -p "${target}"
  inject_shim "${target}/copilot-instructions.md"
  ok "Copilot: shim installed"
}

# =============================================================================
# Project install
# =============================================================================

install_project() {
  local target_dir="${1:-.}"
  local agents_file="${target_dir}/AGENTS.md"

  if [[ -f "$agents_file" ]]; then
    warn "AGENTS.md already exists in ${target_dir}/"
    read -rp "Overwrite? [y/N] " OVERWRITE
    if [[ ! "${OVERWRITE}" =~ ^[Yy]$ ]]; then
      info "Keeping existing AGENTS.md"
      return
    fi
  fi

  cp "${SCRIPT_DIR}/templates/AGENTS.md" "$agents_file"
  ok "AGENTS.md created in ${target_dir}/"

  # SDD v2 spec structure
  mkdir -p "${target_dir}/docs/specs/_templates"

  local spec_template=""
  if [[ -f "${SCRIPT_DIR}/templates/SPEC.template.md" ]]; then
    spec_template="${SCRIPT_DIR}/templates/SPEC.template.md"
  elif [[ -f "${SCRIPT_DIR}/templates/SPEC-TEMPLATE.md" ]]; then
    spec_template="${SCRIPT_DIR}/templates/SPEC-TEMPLATE.md"
  fi

  [[ -n "${spec_template}" ]] && cp "${spec_template}" "${target_dir}/docs/specs/_templates/SPEC.template.md"

  for tmpl in TASKS.template.md TESTS.template.md PROGRESS.template.md; do
    [[ -f "${SCRIPT_DIR}/templates/${tmpl}" ]] && cp "${SCRIPT_DIR}/templates/${tmpl}" "${target_dir}/docs/specs/_templates/"
  done
  ok "SDD v2 templates copied to docs/specs/_templates/"

  # .ai/ working memory
  mkdir -p "${target_dir}/.ai"
  ok ".ai/ working memory directory created"

  # .gitignore
  local gitignore="${target_dir}/.gitignore"
  if [[ -f "$gitignore" ]]; then
    if ! grep -q '^\.ai/' "$gitignore" 2>/dev/null; then
      echo "" >> "$gitignore"
      echo "# AI working memory (SDD v2)" >> "$gitignore"
      echo ".ai/" >> "$gitignore"
      ok ".ai/ added to .gitignore"
    fi
  else
    echo "# AI working memory (SDD v2)" > "$gitignore"
    echo ".ai/" >> "$gitignore"
    ok ".gitignore created with .ai/ rule"
  fi

  # Claude shim
  if [[ ! -f "${target_dir}/CLAUDE.md" ]]; then
    echo "@AGENTS.md" > "${target_dir}/CLAUDE.md"
    ok "CLAUDE.md shim created (@AGENTS.md)"
  elif ! grep -q "@AGENTS.md" "${target_dir}/CLAUDE.md" 2>/dev/null; then
    local tmp
    tmp=$(mktemp)
    echo "@AGENTS.md" > "$tmp"
    echo "" >> "$tmp"
    cat "${target_dir}/CLAUDE.md" >> "$tmp"
    mv "$tmp" "${target_dir}/CLAUDE.md"
    ok "@AGENTS.md prepended to CLAUDE.md"
  fi

  echo ""
  info "Project setup complete."
  info "  Native support: Codex, Copilot, Cursor (read AGENTS.md directly)"
  info "  Claude: CLAUDE.md -> @AGENTS.md"
}

# =============================================================================
# Export
# =============================================================================

export_agents_md() {
  echo ""
  echo "========== AGENTS.md =========="
  echo ""
  cat "${SCRIPT_DIR}/templates/AGENTS.md"
  echo ""
  echo "==============================="
  echo ""
  echo "Copy above content to AGENTS.md in your project root."
  echo ""
}

# =============================================================================
# Main
# =============================================================================

do_tool_install() {
  local tools="$1"
  if [[ -z "$tools" ]]; then
    warn "No AI tools detected. Specify: bash install.sh --tool claude,codex,..."
    return
  fi
  for tool in $tools; do
    info "Installing for ${tool}..."
    case "$tool" in
      claude)  install_claude  ;;
      codex)   install_codex   ;;
      gemini)  install_gemini  ;;
      cursor)  install_cursor  ;;
      copilot) install_copilot ;;
      *)       warn "Unknown tool: ${tool}" ;;
    esac
  done
}

interactive_mode() {
  echo ""
  echo "=== dev-discipline installer v${VERSION} ==="
  echo ""

  local available
  available=$(detect_all)

  if [[ -n "$available" ]]; then
    info "Detected AI tools: ${available}"
  else
    warn "No AI tools detected"
  fi

  echo ""
  echo "Install modes:"
  echo "  1) Global install (detected tools)"
  echo "  2) Project install (AGENTS.md + SDD v2 in current dir)"
  echo "  3) Both (recommended)"
  echo "  4) Export AGENTS.md text"
  echo ""
  read -rp "Choose [1/2/3/4] (default 3): " MODE
  MODE="${MODE:-3}"

  case "$MODE" in
    1) do_tool_install "$available" ;;
    2) install_project "." ;;
    3) do_tool_install "$available"; echo ""; install_project "." ;;
    4) export_agents_md ;;
    *) err "Invalid choice"; exit 1 ;;
  esac
}

main() {
  if [[ $# -eq 0 ]]; then
    interactive_mode
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tool)
        shift
        local tool_arg="${1:-auto}"
        echo ""
        echo "=== dev-discipline installer v${VERSION} ==="
        echo ""
        if [[ "$tool_arg" == "auto" ]]; then
          local available
          available=$(detect_all)
          [[ -z "$available" ]] && { warn "No tools detected"; exit 1; }
          info "Detected: ${available}"
          do_tool_install "$available"
        else
          do_tool_install "${tool_arg//,/ }"
        fi
        shift
        ;;
      --project)
        shift
        local proj_dir="${1:-.}"
        echo ""
        echo "=== dev-discipline installer v${VERSION} ==="
        echo ""
        install_project "$proj_dir"
        shift 2>/dev/null || true
        ;;
      --export)
        export_agents_md
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        err "Unknown option: $1"
        usage
        ;;
    esac
  done
}

main "$@"
