---
id: spec-sre-locate
title: SRE Locate -- 跨 Cluster / Project 的服務與日誌定位工具
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Miyago
tags: [sre, k8s, gcloud, skill]
priority: high
---

# SRE Locate -- 跨 Cluster / Project 的服務與日誌定位工具

## Background

SRE 場景下最常見的窘境不是「不會操作」，而是「不知道要去哪操作」：

- 接到告警，但不知道源頭在哪個 cluster / namespace
- 要查某個 service，但不記得它部署在 develop / production / demo 哪邊
- 要撈 log，但 gcloud project 有三個，每次切換才能 `logging read`
- 跨 cluster 用 `kubectl` 必須手動 `use-context`，誤切到 production 是高風險

目前環境靜態盤點：

- **kubectl contexts**: 5 個 GKE cluster（develop-1386 ×2 / production-1386 ×2 / linen-server-482110 ×1）
- **gcloud projects**: 至少 3 個（develop-1386 / production-1386 / linen-server-482110）
- 既有 skill 已覆蓋 `docker-k8s`、`log-analysis`、`health-check`、`cicd-watch`、`post-mortem`，但缺一個「定位」入口

## Requirements (EARS)

- **R1**: When Miyago 提供一個 keyword（service name / pod prefix / error 片段），the system shall 平行掃過所有已知 kubectl contexts 與 gcloud projects，回報命中位置與 hit count
- **R2**: When 任何 kubectl 命令會修改 cluster state（apply/delete/scale/rollout/edit/patch），the system shall 先顯示 current context + namespace，並在 production cluster 上要求 Miyago 確認
- **R3**: While inventory cache 存在且未過期（預設 6h），the system shall 優先讀取 `.ai/sre-inventory.md` 而非現掃，加速二次定位
- **R4**: When 任何 context / project 認證過期或 cluster 不可達，the system shall 跳過該目標但完成其他目標的掃描，並在輸出標記失敗來源
- **R5**: Where 結果筆數超過上限（預設每 source 50 筆），the system shall 截斷並提示 Miyago 加 filter 或縮小範圍
- **R6**: When skill 被觸發，the system shall 不直接修改任何 cluster / project 狀態，僅執行 read-only 查詢
- **R7**: When 掃描目標包含 GCE VM（透過 SSH），the system shall 從以下三來源取聯集作為 host 清單：(a) `gcloud compute instances list` 跨已知 project、(b) `~/.ssh/config` 定義的 Host、(c) zsh history 高頻 ssh target；在這些 host 上平行 read-only 查詢（`systemctl status` / `journalctl` / `docker ps` / `ss -tlnp`），與 k8s / gcloud 同等彙整輸出

## Non-goals

- 不做動態 cluster discovery（cluster 清單靜態，從 `kubectl config get-contexts` 取）
- 不做 MCP server 化（Phase 1 全 Bash，未踩到 token 痛點不轉 MCP）
- 不做即時 streaming（一次性查詢即可，需要 stream 用 `kubectl logs -f` 或既有 skill）
- 不做寫操作護欄之外的 RBAC 整合（信任 kubeconfig 已正確設定）
- 不做跨雲：只支援 GCP（GKE + GCE VM via SSH），不含 AWS / Azure / on-prem 之外的 cloud provider
- 不做非 GCE 的 host discovery（ssh config 的非 GCE host 仍納入，但不從 AWS / Azure inventory 拉）

## Alternatives Considered

### 方案 A：裝 kubernetes-mcp-server

讓 MCP server 維持 cluster state，跨 session 持續可用。

- 優點：token 效率高、stateful 探索流暢
- 缺點：要維護 server 進程、gcloud auth token 過期會打架、多 cluster auth 設定繁瑣、增加單點故障
- **不選原因**：cluster 清單靜態，沒有 dynamic discovery 需求；現階段 token 痛點不大

### 方案 B：手寫 Go binary

用 Go 寫一個 `sre-locate` CLI，內建 k8s client-go + gcloud SDK。

- 優點：效能最佳、binary 可分發
- 缺點：開發成本高、認證需重做、不利於快速迭代
- **不選原因**：過度工程，Bash 平行 + 既有 CLI 已足夠

### 方案 C（採用）：Bash skill + 既有 CLI 平行掃描

包成 skill，內部 `kubectl --context=X & gcloud --project=Y &` 平行執行，彙整結果。

- 優點：零維護、利用既有 auth、可立即跑、debug 容易
- 缺點：cold start 略慢（被網路延遲限制）、需自己處理結果彙整格式

## Rabbit Holes

1. 不要重寫 `kubectl` / `gcloud` 的 wrapper，只調用，不抽象
2. 不要在 skill 裡做認證 refresh，認證失敗就跳過該 source 並回報
3. 不要試圖支援所有 kubectl resource type，只掃常用四種（pods / services / deployments / configmaps）
4. 不要把 inventory 寫進 git，路徑固定在 `.ai/sre-inventory.md`
5. 不要對 production cluster 做任何寫操作測試，R2 的護欄必須無例外
6. 平行掃描的 timeout 要嚴格（建議 10s/source），不然單一掛掉的 cluster 會卡住整批
7. zsh history 是 meta-encoded（非純 UTF-8），讀取必須用 `strings ~/.zsh_history`，直接 `cat` / `tail` 配 sed 會踩 illegal byte sequence

## Architecture

```text
sre-locate skill
├── 觸發：使用者描述「找不到」/「在哪」/「定位」場景
├── 輸入：keyword + (optional) source filter
│
├── Phase 1: 來源盤點
│   ├── kubectl config get-contexts -o name  →  cluster list
│   └── gcloud config configurations list    →  project list
│
├── Phase 2: 平行掃描（每 source 一個 background job）
│   ├── kubectl --context=$ctx get pods,svc,deploy -A -o wide | grep -i $kw
│   └── gcloud logging read 'textPayload:"$kw"' --project=$proj --freshness=1h
│
├── Phase 3: 結果彙整
│   ├── 標記 source / hit count / 失敗來源
│   └── 截斷到上限，提示縮小範圍
│
├── Phase 4 (optional): 寫入 inventory
│   └── .ai/sre-inventory.md  ←  service → cluster/ns 反向索引
│
└── Phase 5 (R2): 寫操作護欄
    └── PreToolUse hook (kubectl-write-guard.sh) 偵測 apply/delete/scale 等動詞
        在 production context 上要求確認
```

目錄結構：

```text
~/dotfile/config/ai/claude/skills/sre-locate/
  SKILL.md                # skill 入口
  scripts/
    locate.sh             # 主要平行掃描腳本
    inventory-refresh.sh  # 重建 inventory cache
~/dotfile/config/ai/claude/hooks/
  kubectl-write-guard.sh  # R2 護欄（新增）
~/dotfile/.ai/
  sre-inventory.md        # cache（gitignore）
```

## ADR

### ADR-1: Phase 1 不走 MCP，全 Bash 實作

- 決策：用 skill + Bash 平行 `kubectl` / `gcloud`，不裝 kubernetes-mcp-server
- 原因：cluster/project 清單靜態、認證已就位、token 痛點未觸發、維護成本低
- 觸發 re-evaluate 的條件：cluster 數 > 15、出現多 tenant ephemeral env、或 token 用量明顯被輸出量拖累

### ADR-2: 寫操作護欄獨立成 hook，且採嚴格模式

- 決策：R2 寫操作護欄用 `PreToolUse` hook 實作，跟 skill 解耦，且嚴格分級
- 原因：skill 是「使用者觸發」的，hook 是「永遠生效」的；護欄必須無例外
- 嚴格分級：
  - **Tier 1（永遠 ask，無例外）**：任何 cluster 上的 destructive 動詞 -- `delete` / `drain` / `cordon` / `replace` / `taint`
  - **Tier 2（僅 production cluster ask，其他 cluster 只印 context 不擋）**：mutating 動詞 -- `apply` / `patch` / `edit` / `scale` / `rollout restart` / `annotate` / `label` / `set`；判定 production 的方式：current context name 包含 `production` 字串（白名單可在 hook config 擴充）
  - **Tier 3（永遠先顯示 context + namespace 再執行）**：所有 kubectl 寫操作 + `exec` + `cp` + `port-forward`
  - **gcloud 同級**：`gcloud compute instances delete/stop/reset` / `gcloud sql instances delete` / `gcloud secrets delete` 走 Tier 1；`gcloud * update/set-iam-policy` 走 Tier 2
- 影響：護欄即使在沒呼叫 `sre-locate` 時也生效，保護所有寫操作；輕度增加日常打字成本（每次寫操作多一次確認），但 production 風險明顯降低
- 例外白名單：明確由 CI / 信任 caller 觸發的操作不阻擋；判定方式為**環境變數注入** -- caller 設定 `SRE_GUARD_BYPASS=<reason>`（例：`cicd-watch` / `manual-override`），hook 偵測到該變數即放行並記錄 reason
- Tier 3 行為：**只顯示 context + namespace，不寫 log、不阻擋執行**（除非 Miyago 明確要求紀錄）

### ADR-3: Inventory cache TTL 6h，手動 refresh

- 決策：cache 過期不自動 rebuild，由 Miyago 顯式跑 `inventory-refresh.sh`
- 原因：deployment 頻率不一定，6h 平衡新鮮度與 auth 過期風險；自動 refresh 增加複雜度
- 例外：locate 結果為空時，提示「要不要 refresh inventory」

### ADR-4: gcloud logging 預設 freshness=1h

- 決策：日誌掃描只看最近 1 小時
- 原因：incident triage 場景多為近期事件；長時段查詢用既有 `log-analysis` skill
- 可被 caller 覆寫

## Phase 計畫

### Phase 1: locate.sh + 基本平行掃描（k8s + gcloud）

- 實作 `locate.sh`：接 keyword，平行掃所有 kubectl context + gcloud project
- 輸出格式：分 source 列出 hit，附 cluster/ns/resource type
- 支援 `--ns-hint` 選項，從 zsh history 抓最近常用 namespace 優先掃（依 audit，`pms-fine-tune-html-testing` 是主戰場）
- skill SKILL.md 寫好觸發條件 + 用法

### Phase 2: 寫操作護欄 hook（嚴格三層）

- 實作 `ops-write-guard.sh`：偵測 kubectl / gcloud 寫操作動詞，依 ADR-2 三層分級
- 註冊到 `~/.claude/settings.json` 的 PreToolUse
- 加上 CI caller context 白名單
- Tier 1 / Tier 2 / Tier 3 各自獨立測試

### Phase 3: Inventory cache

- 實作 `inventory-refresh.sh`：掃所有 cluster 把 service / deployment 列表寫到 `.ai/sre-inventory.md`
- locate.sh 在掃之前先讀 inventory，命中就跳過該 cluster 的現掃
- TTL 6h，空命中時提示 refresh

### Phase 4: SSH VM 來源整合（R7）

- Host 來源優先序（依 audit 實際 usage 排序）：
  1. **`~/.ssh/config` 靜態 Host**（主要來源 -- 你已 curate 過的清單）
  2. **zsh history 高頻 ssh target**（補充來源 -- `strings ~/.zsh_history` decode 後抓 top N）
  3. **`gcloud compute instances list --project=<each>` 拉 GCE 清單**（輔助來源 -- 用於擴充上面沒覆蓋到的 GCE VM；audit 顯示 gcloud compute 用量低，不當主來源）
- 去重後按 project / 用途分組
- 平行 SSH 跑 read-only 查詢（systemctl / journalctl / docker ps / ss），SSH 選項：`ConnectTimeout=5 BatchMode=yes`
- 與 k8s / gcloud 同等輸出格式
- SSH timeout / auth 失敗的容錯比照 R4
- 走 `gcloud compute ssh` 或直連，依 host 來源決定

### Phase 5 (optional): 整合既有 skill

- 與 `log-analysis` / `health-check` / `post-mortem` 串接，locate 命中後可一鍵接下游

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| 平行掃描某個 cluster 掛掉拖慢整體 | 中 | 嚴格 timeout（10s/source），失敗跳過並標記 |
| gcloud / kubectl auth 過期 | 中 | 偵測 exit code，明確提示重 auth；不在 skill 裡自動 refresh |
| production cluster 誤操作 | 高 | R2 + ADR-2 嚴格三層 hook 護欄 |
| 護欄誤擋 CI 正常 rollout | 中 | ADR-2 白名單：cicd-watch caller context 不阻擋 |
| 護欄打字成本拖慢日常 ops | 低 | Tier 3 只印 context 不阻擋；Tier 1/2 才 ask |
| SSH 平行掃描某 host 卡住 | 中 | SSH ConnectTimeout=5, BatchMode=yes，失敗跳過 |
| GCE host 清單過大導致 SSH 掃描爆量 | 中 | Phase 4 內部 host 數量上限（預設 30），超過要求 filter；只掃 `running` 狀態 |
| zsh history 編碼或路徑異常 | 低 | 拉不到就跳過該來源，靠 gcloud + ssh config 兜底 |
| SRE_GUARD_BYPASS 被誤設常駐 | 中 | 環境變數只在單次命令 inline 設定（`SRE_GUARD_BYPASS=x kubectl ...`），不寫進 shell rc；hook 偵測到非 inline 設定可選擇警告 |
| Inventory cache stale 導致誤判 | 低 | TTL 6h，空命中時主動提示 refresh |
| keyword 太寬命中爆量 | 低 | R5 截斷 + 提示縮小範圍 |
| 跨 project gcloud quota 消耗 | 低 | freshness=1h 限制、limit=50 限制 |
