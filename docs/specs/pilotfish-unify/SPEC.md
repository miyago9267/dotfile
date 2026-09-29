---
id: spec-pilotfish-unify
title: Pilotfish 多 host 整合成單一 source
status: draft
created: 2026-09-29
updated: 2026-09-29
author: Miyago
tags: [pilotfish, orchestration, claude, codex, gemini, grok, opencode]
priority: high
---

# Pilotfish 多 host 整合成單一 source

## Background

Pilotfish 目前有 6 份，各自管理，policy 各自漂移：

| Host | 位置 | 版本 / 狀態 | Role 數 | Model 綁定方式 |
|---|---|---|---|---|
| Claude Code | `Forks/pilotfish-claude`（本機 fork，無 remote） | 1.4.2-claude.1；policy 拆成 bootstrap + skill，另移植 codex 1.8.1 的 7 段規則 | 8 | agent frontmatter alias（opus/sonnet/haiku/fable） |
| Codex CLI | `Forks/pilotfish-codex`（GitHub `miyago9267/pilotfish-codex`） | 1.8.1；674 行 policy，最成熟；上游對照停在 v1.3.0（2026-07-22） | 8（含 `sol-executor`，無 Explore） | `agents/*.toml` 具體 model ID + effort |
| Gemini / agy | `dotfile/plugins/pilotfish-agy` | 無版本；改寫自 pilotfish-grok | 7 | frontmatter 只能填 flash/pro/inherit，沒有 effort |
| Grok Build | `dotfile/plugins/pilotfish-grok` | vendored 上游 `Nanako0129/pilotfish-grok` v1.0.6 | 7 | `model: inherit` + `roles/*.toml` 的 effort |
| OpenCode | `Forks/pilotfish-opencode`（**98 個檔案未 commit**）+ `dotfile/.opencode/pilotfish/*.json` | 0.1.0；TS plugin 負責 route 驗證與 receipt | 5 | `routing.json` 具體 model + fallback |
| 上游 | `Forks/pilotfish`（`Nanako0129/pilotfish`） | v1.4.2；有 `tools/render_plugin_spike.py` 從 templates 產生 Claude plugin | 8 | — |

問題：

- 同一條規則（例如 interaction shape、direction_checkpoint）要在多份 policy 手動移植，已經出現版本落差（claude 用 v1.4.2 + codex 1.8.1 片段，codex 對上游只追到 v1.3.0）。
- 安裝方式有 4 種（dotfile auto-update、`install.sh`、`setup_gemini.sh` 併 rule、手動 AGENT-INSTALL），沒有共同的「目前裝的是哪一版」檢查。
- `pilotfish-claude` 和 `pilotfish-opencode` 只存在本機；後者的工作完全沒 commit。

上游的做法是一個 host 一個 repo，但 policy 本身「不寫 model 名稱、model 只在 role 定義」（上游 `docs/design.md:21`），所以 policy 可以跨 host 共用；上游也已經有「從 templates render 出 host 產物」的工具。本 spec 沿用這兩點，把 6 份收成一個 repo。

## Requirements (EARS)

- **R1**: The repo shall hold exactly one host-neutral policy source（完整 workflow、always-on bootstrap、role / verification / recovery contracts），任何 host 產物中的 policy 文字都由它 render 出來。
- **R2**: The repo shall hold one canonical role catalog，每個 role 定義 contract、存取等級（read-only / write / verify）與 capability tier（fast / standard / strong / frontier），不寫任何 model 名稱。
- **R3**: Where a host is supported，the repo shall hold a host binding：tier 到 model/effort 的對應、role 子集與 fallback（例如 OpenCode 沒有 mech-executor 時改派哪個 role）、host 專屬 role（Claude 的 `Explore`、Codex 的 `sol-executor`）、hooks 與 installer。
- **R4**: When `render --host <h> --check` runs，the tool shall fail if committed host output differs from what the sources would produce。
- **R5**: When migrating a host，the first rendered output shall be byte-identical to that host's **current install source at its committed HEAD**（golden test，比對集合見下表），證明搬家本身沒有改變行為；policy 合併另開 phase。不比對安裝後的檔案，因為 dotfile 會在安裝時拼接 frontmatter / marker（`agent-stack-auto-update.sh:120-136`），`~/.claude/agents/` 也混有非 pilotfish 的 agent。

  | Host | Golden fixture（比對集合） |
  |---|---|
  | claude | `git -C pilotfish-claude archive HEAD templates`：8 個 `agents/*.md`、`skills/pilotfish-orchestration/SKILL.md`、`references/*.md`、`claude-md.bootstrap.md`、`settings.snippet.json` |
  | codex | `pilotfish-codex` HEAD 的 `templates/`（agents `*.toml`、`agents-md.*.md`、`config.snippet.toml`、`hooks.json`） |
  | agy | dotfile HEAD 的 `plugins/pilotfish-agy/templates/` |
  | grok | dotfile HEAD 的 `plugins/pilotfish-grok/templates/` |
  | opencode | P0 commit 後 `pilotfish-opencode` HEAD 的 `src/`、`roles/`，加 dotfile HEAD 的 `.opencode/pilotfish/{catalog,routing}.json` |
- **R6**: Where content is vendored from an upstream（`Nanako0129/pilotfish`、`Nanako0129/pilotfish-grok`），the repo shall record the pinned version in `upstream.lock`，同步只透過人工 diff review。
- **R7**: When dotfile installs or auto-updates any host，it shall read this repo as specified per host below，不再讀 `pilotfish-claude` 或 `pilotfish-opencode`：

  | Host | 取用方式 | 讀 HEAD 還是工作樹 |
  |---|---|---|
  | claude | `agent-stack-auto-update.sh` 用 `git archive HEAD hosts/claude/dist` 安裝 | HEAD |
  | codex | `install.sh` 讀 `hosts/codex/dist`，沿用 `--ref` pinned | HEAD |
  | agy | `setup_gemini.sh` 目前 symlink 到工作樹，**維持 symlink 為明列例外**，改指向 `hosts/agy/dist` | 工作樹（例外） |
  | grok | 維持手動 AGENT-INSTALL，來源改為 `hosts/grok/dist` | HEAD |
  | opencode | `install-pilotfish.sh` 直接從 HEAD 安裝 committed 的 `hosts/opencode/dist/plugin/pilotfish-opencode.js`；`bun install` + build 只在 `render --host opencode --write` 時執行，產物 commit 進 `dist/` | HEAD |

  `dotfile/.opencode/pilotfish/{catalog,routing}.json` 的唯一寫入方是 `render --host opencode --write`（由 `hosts/opencode/binding.toml` 產生後 commit 進 dotfile），禁止手改；`pi-routing.json` 仍由 dotfile 擁有，不在本 spec 範圍。
- **R8**: After a host's golden test passes，each host output shall carry a version marker（沿用 `<!-- pilotfish-<host> vX -->` 慣例），`check_agent_rule_sync.sh` 能驗每個 host 裝的版本。marker 在 P4a 才加入（claude、agy 現有 templates 沒有 marker，先加就不可能 byte-identical）；golden 比對不設豁免。

## Non-goals

- 不在這次合併或改寫 policy 內容（Phase 5 另外決定）。
- 不改 Jev route 與 dispatch guard 的邏輯；它們是 Miyago 個人的 hook，先留在 dotfile，只改它們讀取 source 的路徑。
- 不回頭貢獻上游，也不改變 `pilotfish-codex` 被上游 README 引用的連結可用性。
- 不處理 Pi runtime（`config/ai/pi/PILOTFISH_ROUTING.md`）；它讀 `.opencode/pilotfish/pi-routing.json`，搬家時只保證路徑相容。

## 提議結構

以 `pilotfish-codex` repo 為基底（唯一有 GitHub remote、policy 最新），擴成多 host：

```text
pilotfish/                       # repo 名稱待定，見 Open Decisions
  core/
    policy/orchestration.md      # 從 codex 1.8.1 抽出、去掉 Codex 專屬字眼
    policy/bootstrap.md
    contracts/{role,verification,recovery}.md
    roles.toml                   # R2：canonical role catalog
  hosts/
    claude/  binding.toml  src/  dist/   # src = 尚未中立化的 host 文字；dist = committed 產物
    codex/   binding.toml  render.py  hooks/  install/  dist/
    agy/     binding.toml  render.py  dist/
    grok/    vendor/pilotfish-grok@v1.0.6/  binding.toml  dist/
    opencode/ src/ (TS plugin)  roles/  binding.toml(= routing.json 來源)  dist/
  tools/render.py                # --host <h> --check|--write，每個 host 一個 render 函式
  tests/                         # golden、role parity、policy invariants
  upstream.lock
```

`roles.toml` 的樣子（示意；repo 沒有 PyYAML，設定檔一律用 stdlib `tomllib` 可讀的 TOML）：

```toml
[roles.scout]
access = "read-only"
tier = "fast"
security = false

[roles.security-executor]
access = "write"
tier = "strong"
security = true
# 其餘 role 同格式：mech-executor / executor = standard，plan-verifier = frontier，verifier / security-reviewer = strong
```

`hosts/claude/binding.toml`（示意，數值等於目前已上線的設定）：

```toml
[tiers]
fast = "sonnet"
standard = "sonnet"
strong = "opus"
frontier = "fable"   # render 驗證：security role 不得解析成 frontier 的 model

[roles.executor]
effort = "high"
# description、tools / disallowedTools 也在這裡

[extra_roles.Explore]
model = "haiku"
effort = "low"
```

## Alternatives Considered

### 方案 A：單一 monorepo，以 pilotfish-codex 為基底（推薦）

- 優點：一個 remote、一次 commit 就能讓所有 host 同步一條規則；codex 已經有最完整的 installer、測試與 spec 流程。
- 缺點：repo 名稱和 README 要改；codex 的 installer 目前寫死單一 host，要拆。

### 方案 B：全部收進 dotfile `plugins/pilotfish/`

- 優點：跟其他個人設定同 repo，不用另外管 remote。
- 缺點：dotfile 是私人 config，pilotfish-codex 是公開專案且被上游引用；混在一起會讓公開內容跟著私人 WIP 走。

### 方案 C：維持每 host 一個 repo，只加共用 `pilotfish-core` 當 submodule

- 優點：最接近上游的模式。
- 缺點：submodule 同步本身就是另一種「分開管理」，沒有解決 Miyago 的痛點。

## P1 實作決策

- P2：codex 的 dist 就是既有 `templates/`（不另開 `hosts/codex/dist/`），因為 installer、既有測試與遠端 `--ref` raw URL 安裝都寫死這個路徑；R7 表中 codex 的「讀 `hosts/codex/dist`」以此為準。
- P2：`mech-executor` 的 tier 由 standard 改為 fast（codex 的 mech 與 executor 用不同 model；Claude 的 fast 與 standard 同為 sonnet，產出不變）。
- P2：「security role 不得解析到 frontier model」改為 binding 的 `security_avoid_frontier` 開關（claude=true、codex=false），這條限制源自 Anthropic frontier model 的分類器，不是跨 host 通則。
- P3：binding 新增 `omitted_roles`（opencode 不提供 mech-executor、plan-verifier）與 `supports_effort`（agy 為 false，render 不輸出 effort）；`validate_catalog` 要求每個 core role 在 binding 有對應或列在 `omitted_roles`。
- P3：opencode 的 TS plugin 放 `hosts/opencode/plugin/`（不經 render），`install/install.sh` 改讀 render 產出的 `hosts/opencode/dist/roles/`；grok 上游文字 vendored 在 `hosts/grok/src/`，版本記在根目錄 `upstream.lock`。
- policy 文字在 P1 放 `hosts/claude/src/`，不放 `core/policy/`：claude 與 codex 的 policy 已分岔，硬放進 core 會讓 R1 名不副實；`core/` 在 P1 只有 `roles.toml`，R1 於 P5 達成。

## Rabbit Holes

- **一開始就合併 policy**：claude（v1.4.2 + 片段）和 codex（1.8.1）的 policy 已經分岔，先搬家再合併；R5 的 golden test 就是為了把這兩件事拆開。
- **想用一個通用 template 語言產生所有 host**：各 host 的格式差太多（md frontmatter、TOML、TS、JSON），每個 host 一個小 render 函式比較簡單。
- **把 Codex 的 2581 行 `install.py` 泛化成通用 installer**：不做，各 host 保留自己的 installer，只把 source 路徑改到 `dist/`。
- **agy 沒有 effort、只接受 flash/pro/inherit**：binding 要能表達「此 host 不支援這個欄位」，不要硬塞。

## Phases

| Phase | 內容 | 驗收 | 估時 |
|---|---|---|---|
| P0 保全 | `pilotfish-opencode` 的 98 個未 commit 改動在本機分支 commit | `git status` 乾淨 | 5 分鐘 |
| P1 骨架 + Claude | 建 `core/`、`roles.toml`、`tools/render.py`；Claude renderer 產出與 R5 的 claude fixture 位元組相同 | golden test 綠、`render --check` 綠 | 2–3 小時 |
| P2 Codex | 現有 codex templates 改由 renderer 產生，installer 改讀 `dist/` | golden 綠、codex 既有測試綠、`install.sh --dry-run` 無差異 | 2–3 小時 |
| P3 agy / grok / opencode | 搬入三個 host；grok 以 vendor + lock 方式保留 | 各自 golden 綠、opencode `bun build` 成功 | 3–4 小時 |
| P4a 切換 + marker | `feat/multi-host` merge 進 main；`agent-stack-auto-update.sh`、`install-pilotfish.sh`、`setup_gemini.sh`、`check_agent_rule_sync.sh` 改讀新 repo（R7 表）；加上 R8 marker | setup dry-run 無差異、auto-update 成功一次、`check_agent_rule_sync.sh` 綠 | 1 小時 |
| P4b 封存 | 舊 `pilotfish-claude`、`pilotfish-opencode` 移到 archive | 前置條件：P4a 之後連續 7 天 auto-update 成功 | 10 分鐘 |
| P5 policy 合併 | 決定 canonical policy（建議以 codex 1.8.1 為主，補上游 v1.4.2 之後的變更），各 host 重新 render | 另開 spec | 另估 |

P1–P4 每個 phase 結束時，所有 host 的實際行為都不變；P5 才會改變行為。

**Rollback**

- P1–P3：只存在 `pilotfish-codex` 的 `feat/multi-host` branch，main 和 dotfile 都沒動，刪 branch 即可。
- P4a：revert dotfile 的切換 commit，auto-update 下次執行就從舊 fork 裝回；舊 fork 目錄在 P4b 之前都保留原樣。
- P4b 之後：舊 fork 在 archive 目錄仍可還原。

## P4a 執行切片（2026-09-29，送審版）

前置：P1–P3 已 commit（`pilotfish-codex@9d07203` 的 `feat/multi-host`，dotfile `ddcc129`）。

**不在此切片**：GitHub 改名與任何 push（external mutation，另外確認）；刪除 dotfile `plugins/pilotfish-agy`、`plugins/pilotfish-grok` 與舊 fork（P4b）。

| 步驟 | 動作 | 驗收 |
|---|---|---|
| S1 | `pilotfish-codex` 本機 `main` fast-forward merge `feat/multi-host` | `git log main` 含 `9d07203`；5 host `--check` 綠 |
| S2 | R8 marker：claude 放在 `skills/pilotfish-orchestration/SKILL.md` 的 frontmatter 之後、body 第一行（`<!-- pilotfish-claude vX -->`，auto-update 會把它裝進 `pilotfish:begin/end` 之間）；agy 放在 `rules/pilotfish-agy.md` 第一行（`setup_gemini.sh` 會併入 generated `GEMINI.md`）；codex、grok 已有；opencode 輸出全是 JSON，不加，改由 S6 的內容比對驗證。golden 改為 regression fixture：`refresh_golden.py` 新增 `--from-dist` 模式，從本 repo 的 `DIST_DIRS[host]` 複製並在 `SOURCE` 記 `shoal@<sha>`；同步更新各 test 的 `SOURCE_REFS` / `GOLDEN_COUNT` | 5 host `--check` 綠、`unittest discover` 全綠、`tests/golden/*/SOURCE` 記錄新來源 |
| S3 | 目錄改名 `Forks/pilotfish-codex` → `Forks/shoal`，並建 symlink `Forks/pilotfish-codex -> shoal` 作為過渡相容（P4b 移除） | 舊路徑仍可讀；`git -C Forks/shoal status` 正常 |
| S4 | `~/.codex/config.toml:311` marketplace `source` 改指 `Forks/shoal/plugin`（改前備份） | `tomllib` 可解析；路徑存在 |
| S5 | dotfile 單一 commit 切換：`agent-stack-auto-update.sh` 改從 `shoal` HEAD `git archive hosts/claude/dist` 安裝；`install-pilotfish.sh` 改為 `git archive` HEAD 的 `hosts/opencode` 到暫存目錄 → `bun install --frozen-lockfile` → `bun run build` → 安裝 js（取代 R7 表中「committed dist js」，plan-verifier 第 2 輪允許的替代方案；repo 不 commit 產物）；`setup_gemini.sh` symlink 改指 `shoal/hosts/agy/dist`；`claude/AGENTS.md`、skill 說明、`config/ai/grok/README.md`、`PILOTFISH_ROUTING.md` 的路徑文字改為 `shoal` | 單一 commit，可整個 revert |
| S6 | `.opencode/pilotfish/{catalog,routing}.json` 維持 dotfile 內的一般檔案（可攜），由 `check_agent_rule_sync.sh` 比對必須與 `shoal/hosts/opencode/dist` 逐位元組相同；`check_agent_rule_sync.sh` 另加 marker 檢查，對象是**實際安裝處**：`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/pilotfish-orchestration/SKILL.md` 與 generated `GEMINI.md` | 併入 S5 的 commit；刪掉已安裝檔中的 marker 行時 sync check 必須失敗 |
| S7 | 驗證：切換前快照 `~/.claude/agents`、skill、`plugins/pilotfish-opencode.js`、`~/.gemini` 的 pilotfish 連結；切換後各跑一次 auto-update、`install-pilotfish.sh`、`setup_gemini.sh`（或其 pilotfish 段）、`check_agent_rule_sync.sh` | agents 與 skill 內容和切換前相同（marker 除外）；opencode js 與切換前 build 相同或只差路徑註解；gemini 連結指向 shoal；sync check 綠 |

**Rollback**：revert S5 的 dotfile commit；`~/.codex/config.toml` 用 S4 的備份還原；S3 的 symlink 讓舊路徑持續可用；S1/S2 只在本機 `main`，可 `git reset` 回 `61a411b`（需另確認）。

## Open Decisions

1. **Repo 名稱**：沿用 `pilotfish-codex` 改名（GitHub 會自動轉址，上游連結不會斷），或開新 repo `pilotfish-hosts` 之類，把 codex 歷史搬進去？
   - **已定（不擋 P1）**：P1–P3 在本機 `~/Project/Active/Forks/Fork-Remaster-code/pilotfish-codex` 的 `feat/multi-host` branch 進行，不動 main、不 push。P4 各 script 的預設路徑就用這個本機路徑；若最後選擇改名，只需在 P4a 前改一次目錄名稱和這些路徑。
   - **已定（2026-09-29）**：repo 改名為 `shoal`（GitHub `miyago9267/shoal` 可用；改名後舊 URL 自動轉址）。只改 repo 名稱；各 host 的輸出名稱（`pilotfish-codex` plugin、`<!-- pilotfish-<host> vX -->` marker、`~/.codex` 備份檔名、`check_agent_rule_sync.sh`）一律不變。改名在 P4a 執行。
2. **grok**：繼續 vendor 作者的 `pilotfish-grok`，還是改成自己的 binding，跟其他 host 一樣由 core render？
3. **dispatch guard / Jev route**：先留在 dotfile（本 spec 的預設），還是在 P5 之後收進 `hosts/claude/hooks/`？
