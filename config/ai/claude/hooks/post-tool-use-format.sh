#!/bin/bash
# Post-tool-use hook: auto format & lint after file writes
# 自動偵測專案的 formatter/linter，不綁死工具

set -euo pipefail

# 只在 Write/Edit 工具後觸發
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# 取得被修改的檔案路徑
FILE_PATH="${CLAUDE_FILE_PATH:-}"
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# 取得檔案所在目錄，用來找專案根目錄
FILE_DIR="$(dirname "$FILE_PATH")"
EXT="${FILE_PATH##*.}"

# --- 往上找專案根目錄 ---
find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" || -f "$dir/go.mod" || -f "$dir/pyproject.toml" || -f "$dir/Cargo.toml" || -f "$dir/.git" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  echo ""
}

PROJECT_ROOT="$(find_project_root "$FILE_DIR")"
if [[ -z "$PROJECT_ROOT" ]]; then
  exit 0
fi

cd "$PROJECT_ROOT"

# --- Markdown lint fix（無論專案有無 config 都跑，吃 ~/.markdownlint.json 全域設定）---
fix_markdown() {
  local file="$1"
  if command -v markdownlint-cli2 &>/dev/null; then
    markdownlint-cli2 --fix "$file" 2>/dev/null || true
  elif command -v markdownlint &>/dev/null; then
    markdownlint --fix "$file" 2>/dev/null || true
  elif command -v npx &>/dev/null; then
    npx --yes markdownlint-cli2 --fix "$file" 2>/dev/null || true
  fi
}

# --- Format ---
format_file() {
  local file="$1"

  # Biome (優先)
  if [[ -f "biome.json" || -f "biome.jsonc" ]]; then
    if command -v biome &>/dev/null; then
      biome format --write "$file" 2>/dev/null || true
      return
    elif command -v npx &>/dev/null; then
      npx --yes @biomejs/biome format --write "$file" 2>/dev/null || true
      return
    fi
  fi

  # Prettier
  if [[ -f ".prettierrc" || -f ".prettierrc.json" || -f ".prettierrc.js" || -f ".prettierrc.yaml" || -f "prettier.config.js" || -f "prettier.config.mjs" ]]; then
    if command -v prettier &>/dev/null; then
      prettier --write "$file" 2>/dev/null || true
      return
    elif command -v npx &>/dev/null; then
      npx --yes prettier --write "$file" 2>/dev/null || true
      return
    fi
  fi

  # Go
  if [[ "$EXT" == "go" ]]; then
    if command -v gofmt &>/dev/null; then
      gofmt -w "$file" 2>/dev/null || true
    fi
    return
  fi

  # Python (ruff > black)
  if [[ "$EXT" == "py" ]]; then
    if command -v ruff &>/dev/null; then
      ruff format "$file" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black -q "$file" 2>/dev/null || true
    fi
    return
  fi

  # Rust
  if [[ "$EXT" == "rs" ]]; then
    if command -v rustfmt &>/dev/null; then
      rustfmt "$file" 2>/dev/null || true
    fi
    return
  fi
}

# --- Lint (check only, don't auto-fix to avoid unexpected changes) ---
lint_file() {
  local file="$1"

  # Biome
  if [[ -f "biome.json" || -f "biome.jsonc" ]]; then
    if command -v biome &>/dev/null; then
      biome lint "$file" 2>/dev/null || true
      return
    fi
  fi

  # ESLint
  if [[ -f ".eslintrc.js" || -f ".eslintrc.json" || -f ".eslintrc.yaml" || -f ".eslintrc.yml" || -f "eslint.config.js" || -f "eslint.config.mjs" ]]; then
    if command -v eslint &>/dev/null; then
      eslint --no-error-on-unmatched-pattern "$file" 2>/dev/null || true
      return
    fi
  fi

  # Go vet
  if [[ "$EXT" == "go" ]]; then
    if command -v go &>/dev/null; then
      go vet "./$(dirname "${file#$PROJECT_ROOT/}")/..." 2>/dev/null || true
    fi
    return
  fi

  # Python (ruff > flake8)
  if [[ "$EXT" == "py" ]]; then
    if command -v ruff &>/dev/null; then
      ruff check "$file" 2>/dev/null || true
    elif command -v flake8 &>/dev/null; then
      flake8 "$file" 2>/dev/null || true
    fi
    return
  fi
}

# --- 執行 ---
case "$EXT" in
  md)
    fix_markdown "$FILE_PATH"
    ;;
  ts|tsx|js|jsx|vue|json|css|scss|html|yaml|yml)
    format_file "$FILE_PATH"
    lint_file "$FILE_PATH"
    ;;
  go)
    format_file "$FILE_PATH"
    lint_file "$FILE_PATH"
    ;;
  py)
    format_file "$FILE_PATH"
    lint_file "$FILE_PATH"
    ;;
  rs)
    format_file "$FILE_PATH"
    ;;
  *)
    # 不認識的副檔名，跳過
    ;;
esac
