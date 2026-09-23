---
id: spec-pilotfish-agy
title: Pilotfish orchestration on agy (Antigravity CLI)
status: done
created: 2026-09-23
updated: 2026-09-23
author: Miyago
tags: [pilotfish, agy, antigravity, orchestration]
priority: medium
---

# Pilotfish orchestration on agy (Antigravity CLI)

## Background

agy 預設主 session 跑 Gemini 3.8 Flash，沒有角色分工，也沒有 plan / approval /
verification gate。Claude、Codex、OpenCode、Grok 都已有 pilotfish port，agy 沒有。

2026-09-23 已在 agy 1.2.9 實測確認：

- 自訂 agent 放在 `~/.gemini/config/agents/<name>/agent.md`，`agy agents` 可列出，
  主 agent 可用 `invoke_subagent` 呼叫。
- frontmatter `model: pro` 生效（subagent 實際跑 `gemini-3.1-pro-low`）。
- `model` 只接受 tier（`flash` / `pro` / `inherit`）；填具體 model ID
  （`gemini-3.1-pro-high`、`claude-opus-4-6-thinking`、`claude`）會讓 agent
  失效（`not found or not allowed to be invoked`）。
- global skills 讀 `~/.gemini/config/skills/`；global rules 目前經由
  `~/.gemini/GEMINI.md` 載入；user/workspace rules 有 20,000 token 預算。

## Requirements (EARS)

- **R1**: When `setup_gemini.sh` runs, the system shall install 7 pilotfish roles
  (`scout`, `plan-verifier`, `security-reviewer`, `mech-executor`, `executor`,
  `verifier`, `security-executor`) into `~/.gemini/config/agents/<role>/agent.md`
  as symlinks, and `agy agents` shall list all 7.
- **R2**: When the main session invokes `scout` or `mech-executor`, the subagent
  shall run on the Flash tier; when it invokes any other role, the subagent shall
  run on the Pro tier (evidence: conversation DB model field).
- **R3**: If `scout`, `plan-verifier` or `security-reviewer` attempts a file write,
  then agy shall deny it.
- **R4**: Where the role is `verifier`, the agent shall have no file-edit tools
  but keep `run_command` for tests（shell 本身仍可寫檔，與 Claude pilotfish 的
  verifier 限制相同，由 prompt 約束）。
- **R5**: When a task is large, architectural, risky or cross-surface, the main
  session shall load the `pilotfish-orchestration` skill and follow its gates
  (plan -> plan-verifier -> Miyago approval -> execute -> fresh verifier).
- **R6**: While pilotfish is installed, the always-on rule text it adds shall stay
  under 1,500 tokens, so the composed global rules stay well inside the 20k budget.
- **R7**: The system shall not force the main-session model; Miyago keeps choosing
  it via `/model` or `--model`.

## Non-goals

- 不把 Claude / GPT-OSS 當 subagent（agy 不支援；需要時走既有 `agent-call`
  headless job，本 spec 不改它）。
- 不做 `Explore` 角色（那是 shadow Claude 內建 Explore 用的，agy 不需要）。
- 不改 Gemini CLI（`~/.gemini/skills`、`policies`）的行為。
- 不發成獨立 repo / release；先放 dotfile 內可用。

## Alternatives Considered

### 方案 A：整份 policy 當 always-on rule（Grok port 做法）

Grok 的 rules 約 16KB，加上現有 GEMINI.md 10KB，每個 turn 都吃掉大量 rule 預算，
而且 Flash 主 session 對長 rule 的遵循度差。不選。

### 方案 B：短 rule + skill（Claude port 做法，採用）

always-on rule 只放角色名單、何時載入 skill、硬性 gate；完整流程放
`pilotfish-orchestration` skill，需要時才載入。

### 方案 C：包成 agy plugin

plugin 目前文件只列 skills / rules / hooks / MCP，沒有 agents；要混兩種安裝面，
不比直接 symlink 簡單。不選，之後 agy plugin 支援 agents 再評估。

## Rabbit Holes

1. 不要在 frontmatter 放具體 model ID，會讓 agent 靜默失效（已實測）。
2. 不要把常駐 rule 放 `~/.gemini/config/rules/`：Phase 1 實測 agy 不讀；改併入
   `compose_active_rules` 產生的 `~/.gemini/GEMINI.md`。

## Phase 1 探測結果（2026-09-23，agy 1.2.9）

- agent.md 標準格式（取自 agy `define_subagent` 自己產生的檔案）：YAML
  frontmatter，後面接 `# Agent System Instructions` H1 標題與 prompt 內文。
  可用欄位：`name`、`description`、`model`、`tools`、`hidden`、`subagent`、
  `mainAgent`、`inheritCustomizations`、`inheritMcp`、`commandExecutionPolicy`、
  `excludeDefaultComponents`、`skills`、`agents`。
- `tools:` 清單是硬限制：probe agent 只給 `view_file`、`grep_search`，連
  `--dangerously-skip-permissions` 下也寫不了檔（回報 no tool），R3 可達成。
- 照上述格式寫的 system prompt 會被遵守（probe 每次都以指定 token 開頭）。
- headless（`-p`）下 `run_command` 需要 settings.json allow 規則，否則自動拒絕；
  互動模式照常詢問。

## Architecture

```text
plugins/pilotfish-agy/
  README.md
  templates/
    agents/<role>/agent.md        # 7 份，frontmatter: name, description, subagent, model, tools/policy
    rules/pilotfish-agy.md        # 短 always-on rule（< 1.5k tokens），由 setup 併入 GEMINI.md
    skills/pilotfish-orchestration/SKILL.md   # 完整流程，由 grok rules 改寫
  tests/test_templates.py         # 靜態檢查
  tests/e2e.sh                    # 用 agy -p 驗 R1-R4

script/common/setup_gemini.sh     # 新增：link agents、skill、rule
```

| 層 | agy 位置 | 內容 |
|---|---|---|
| Roles | `~/.gemini/config/agents/<role>/agent.md` | 角色契約、tier、權限 |
| Policy（常駐） | 併入 `~/.gemini/GEMINI.md`（`compose_active_rules`） | 角色名單、觸發條件、硬 gate |
| Policy（按需） | `~/.gemini/config/skills/pilotfish-orchestration/` | routing、plan/approval、dispatch、verification、recovery |

| Role | Tier | 權限 |
|---|---|---|
| `scout` | flash | read-only |
| `mech-executor` | flash | read + write + shell |
| `plan-verifier` | pro | read-only |
| `security-reviewer` | pro | read-only |
| `executor` | pro | read + write + shell |
| `verifier` | pro | read + `run_command`，無 edit 工具 |
| `security-executor` | pro | read + write + shell |

## ADR

### ADR-1: policy 只寫角色名，不寫 tier

- 決策：rule / skill 只提角色名；tier 只在 agent.md。
- 原因：與其他 port 一致，之後換 tier 不必改 policy。

### ADR-2: 內容從 pilotfish-grok 改寫，不重新設計

- 決策：角色 prompt 與流程以 `plugins/pilotfish-grok/templates/` 為來源，只換
  agy 原生語彙（`invoke_subagent`、tier、權限欄位）。
- 原因：流程已在其他 runtime 驗證過，避免分歧。

## Phase 計畫

### Phase 1: 格式探測（已完成）

- 結果見「Phase 1 探測結果」。

### Phase 2: 樣板與安裝（約 60 分鐘）

- 7 份 agent.md、短 rule、skill；`setup_gemini.sh` 安裝；靜態測試（Red -> Green）。

### Phase 3: 端對端驗證（約 30 分鐘）

- `tests/e2e.sh` 驗 R1-R4；fresh `verifier` 驗一次；清掉 probe 產物。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| verifier 透過 shell 寫檔 | 驗證時改到 code | prompt 禁止；與 Claude pilotfish 同等級限制，README 標明 |
| agy 版本更新改變 agent.md 格式 | agent 靜默失效 | e2e.sh 檢查 `agy agents` 列出 7 個，setup 後可重跑 |
| Pro 額度消耗增加 | quota 用完 | 只有 5 個 Pro 角色，且僅在 pilotfish 觸發時使用；scout / mech 走 Flash |
| Flash 主 session 不遵循 gate | 流程被跳過 | 常駐 rule 保持短而硬；建議複雜任務主 session 切 Pro |
