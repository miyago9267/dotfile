---
spec: automation-routing-hardening
batch: 1
created: 2026-05-12
---

# Tests: Automation Routing Hardening for Skills, Hooks, and MCP

> Spec: `docs/specs/automation-routing-hardening/SPEC.md`

## 驗收條件 (EARS)

### R1: When a shared skill is authored or updated, the system shall require consistent routing metadata including `when_to_use`, `tags`, `effort`, `shell`, and `runtime-scope`

- **When**: 檢查 shared contract 與 skill creator 模板
- **Shall**: 欄位定義存在且模板已同步
- **驗證方式**: 文件審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R6: When Claude runtime automation is expanded, the system shall add high-value event hooks for `InstructionsLoaded`, `CwdChanged`, `PreCompact`, `PostCompact`, `SubagentStop`, and `TaskCompleted`

- **When**: 檢查 Claude settings hooks
- **Shall**: 事件設定存在
- **驗證方式**: `jq '.hooks' settings.json`
- **狀態**: [ ] 未驗證 / [x] 通過

### R8: When high-frequency skills are updated, the system shall backfill the new metadata without changing their core workflow semantics

- **When**: 檢查 10 個高頻 skill frontmatter
- **Shall**: metadata 齊全且正文流程未被重寫
- **驗證方式**: 抽查 frontmatter + diff
- **狀態**: [ ] 未驗證 / [x] 通過
