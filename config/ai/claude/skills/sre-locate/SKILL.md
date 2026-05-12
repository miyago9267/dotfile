---
name: sre-locate
description: "跨 cluster / project / VM 的服務與日誌定位 -- 觸發：使用者說「找不到」、「在哪個 cluster/namespace/project」、「定位服務」、「locate service」、「哪邊有 X」。Read-only，不修改任何狀態。"
alwaysApply: false
---

# SRE Locate -- 跨 Cluster / Project 的定位入口

## 何時觸發

使用者表達「不知道要去哪找」的場景：

- 「這個 service 部署在哪？」
- 「告警寫 X 服務有問題，可是我不知道在哪個 cluster」
- 「ECONNREFUSED 是哪個 namespace 來的？」
- 「最近一小時內哪邊出了 OOM？」

不是用來操作 cluster，是用來**找出該去哪操作**。後續寫操作走既有 `docker-k8s` skill。

## 核心承諾

1. **Read-only** -- 任何 cluster / project 狀態不會被修改
2. **平行掃描** -- 同時打 5 cluster + 3 project，每 source 10s timeout
3. **部分失敗容錯** -- 一個 source 掛掉不會拖垮整批
4. **結果分 source 彙整** -- 你看完知道接下來該 `kubectl --context=X -n Y` 或 `gcloud --project=Z` 進去挖

## 使用方式

```bash
bash ~/dotfile/config/ai/claude/skills/sre-locate/scripts/locate.sh <keyword> [options]
```

### Options

| flag | 預設 | 說明 |
|---|---|---|
| `--source=k8s\|gcp\|all` | `all` | 限定來源 |
| `--ns-hint=<ns>` | -- | 優先掃這個 namespace（提升相關 hit 排序） |
| `--freshness=<dur>` | `1h` | gcloud logging 時間窗 |
| `--limit=<n>` | `50` | 每 source 最大 hit 數 |
| `--timeout=<sec>` | `10` | 每 source 超時 |
| `--no-cache` | -- | Phase 3 啟用後可跳過 inventory cache |

### 典型使用

```bash
# 找一個 service 在哪
bash ~/dotfile/config/ai/claude/skills/sre-locate/scripts/locate.sh fine-tune

# 查近 30 分鐘的 error，限定 gcp logging
bash ~/dotfile/config/ai/claude/skills/sre-locate/scripts/locate.sh ECONNREFUSED \
  --source=gcp --freshness=30m

# 已知主戰場 namespace，給 hint 加速
bash ~/dotfile/config/ai/claude/skills/sre-locate/scripts/locate.sh nginx \
  --ns-hint=pms-fine-tune-html-testing
```

## 輸出格式

```text
# sre-locate: keyword='X' source=all elapsed=8s

## kubectl
  [3 hits]   gke_develop-1386_asia-east1-a_dq-line-vpc-cluster
    default     pod/foo-abc       Running   1/1
    ...
  [no hits]  gke_production-1386_asia-east1_production-cluster
  [timeout]  gke_linen-server-482110-m0_asia-east1_demo-cluster-cluster
  [error]    gke_develop-1386_asia-east1-c_standard-cluster

## gcloud logging
  [12 hits]  develop-1386
    2026-05-12T03:24:01Z  cluster=...  ns=...  ECONNREFUSED ...
  [no hits]  production-1386
  ...

## summary
  total hits: 15
  failed sources:
    - k8s:gke_linen-...-cluster (timeout)
    - k8s:gke_develop-1386_asia-east1-c_standard-cluster (auth/connect)
```

## 規則

1. **不要直接跑寫操作** -- 這 skill 只定位；要動 cluster 切到 `docker-k8s` skill
2. **結果不足時，先放寬 freshness / 改 keyword，不要立刻 refresh inventory**（Phase 3 啟用後）
3. **看到 `[timeout]` / `[error]` 標記，先確認 auth：`gcloud auth login` / `gcloud container clusters get-credentials`**
4. **不要把 keyword 設太寬**（例：單一字母）-- 會觸發 limit 截斷，浪費 token

## 與其他 skill 銜接

```text
sre-locate (定位)
  |- 找到 service 但要排查 pod 狀態
  |    -> docker-k8s skill
  |
  |- 找到 log pattern 要深挖
  |    -> log-analysis skill
  |
  |- 找到 service 但連不上
  |    -> health-check skill
  |
  |- 排查完要記錄
  |    -> /post-mortem
```

## Phase 狀態

- Phase 1（k8s + gcloud 掃描）: 完成
- Phase 2（寫操作護欄 hook）: 完成
- Phase 3（inventory cache）: 完成
- Phase 4（SSH VM 來源）: 完成
- Phase 5（與既有 skill 串接）: 文件層串接，無新增程式碼

詳細設計見 `docs/specs/sre-locate/SPEC.md`。
