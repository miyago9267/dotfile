#!/bin/bash
# Global Skill Creator — 在任何專案建立新 skill
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/skill-create.sh <name> <description> [--always-apply]
#
# 建立結構：
#   ${CLAUDE_PLUGIN_ROOT:-~/.claude}/skills/<name>/SKILL.md        (全域 skill)
#   或 <project>/skills/<name>/SKILL.md     (專案 skill，加 --project)
#
# 範例:
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/skill-create.sh auto-test "自動跑測試並記錄結果"
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/skill-create.sh code-review "PR review 規範" --always-apply
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/skill-create.sh my-lint "Lint 規則" --project

set -e

NAME="$1"
DESC="$2"
shift 2 2>/dev/null || true

ALWAYS_APPLY=false
PROJECT_MODE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --always-apply) ALWAYS_APPLY=true; shift ;;
    --project) PROJECT_MODE=true; shift ;;
    *) shift ;;
  esac
done

if [ -z "$NAME" ] || [ -z "$DESC" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/skill-create.sh <name> <description> [--always-apply] [--project]"
  echo ""
  echo "Options:"
  echo "  --always-apply   Set alwaysApply: true (skill always active)"
  echo "  --project        Create in project's skills/ instead of ${CLAUDE_PLUGIN_ROOT:-~/.claude}/skills/"
  exit 1
fi

# 決定目標路徑
if [ "$PROJECT_MODE" = true ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  SKILL_DIR="$PROJECT_ROOT/skills/$NAME"
  SCRIPTS_DIR="$SKILL_DIR/scripts"
else
  SKILL_DIR="$HOME/.claude/skills/$NAME"
  SCRIPTS_DIR=""  # 全域 skill 通常不需要 scripts 子目錄
fi

if [ -d "$SKILL_DIR" ]; then
  echo "ERROR: Skill '$NAME' already exists at $SKILL_DIR"
  exit 1
fi

mkdir -p "$SKILL_DIR"

# 產生 SKILL.md
ALWAYS_LINE="false"
[ "$ALWAYS_APPLY" = true ] && ALWAYS_LINE="true"

cat > "$SKILL_DIR/SKILL.md" << EOF
---
name: $NAME
description: $DESC
alwaysApply: $ALWAYS_LINE
---

# $NAME

## Purpose
$DESC

## Rules
<!-- 在此定義行為規則 -->

1. (規則一)
2. (規則二)

## Workflow
<!-- 定義工作流程 -->

### Trigger
- 觸發條件描述

### Actions
1. 步驟一
2. 步驟二

## Anti-patterns
- 不要做的事情
EOF

# 專案模式：額外建 scripts 目錄和範本腳本
if [ "$PROJECT_MODE" = true ]; then
  mkdir -p "$SCRIPTS_DIR"
  cat > "$SCRIPTS_DIR/main.ts" << 'TSEOF'
#!/usr/bin/env bun
/**
 * Skill 主腳本
 *
 * 用法: bun run skills/<name>/scripts/main.ts [args]
 */

const args = process.argv.slice(2)

if (args.includes("--help") || args.includes("-h")) {
  console.log("Usage: bun run this-script.ts [args]")
  process.exit(0)
}

// TODO: 實作 skill 邏輯
console.log("Skill executed with args:", args)
TSEOF
  echo "Created: $SCRIPTS_DIR/main.ts"
fi

echo "Skill created: $SKILL_DIR/SKILL.md"
echo ""
echo "Next steps:"
echo "  1. Edit $SKILL_DIR/SKILL.md to define rules and workflow"
if [ "$PROJECT_MODE" = true ]; then
  echo "  2. Edit $SCRIPTS_DIR/main.ts to implement logic"
  echo "  3. Register in skills/run.ts COMMANDS table"
fi
echo "  Tip: Use 'alwaysApply: true' for skills that should always be active"
