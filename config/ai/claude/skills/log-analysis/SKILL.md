---
name: log-analysis
description: "日誌分析方法論 -- 觸發：使用者分享 log、提到錯誤日誌、debug production、查 log。系統性從日誌中抓 pattern，區分 signal 和 noise。"
alwaysApply: false
---

# 日誌分析方法論

分析日誌時用結構化方法，不要一次 dump 整個 log，不要看到第一個 error 就下結論。

## 觸發條件

- 使用者分享 log 片段或要求分析日誌
- 使用者提到「看 log」「查 log」「debug production」
- 需要從日誌中定位問題根因

## 分析流程（每步有判定 + 分流）

```text
Step 1: 確定時間範圍 -> 輸出 TIME_RANGE + SOURCE
Step 2: 取得日誌     -> 輸出 RAW_LOGS（限定行數）
Step 3: 過濾 signal  -> 輸出 TOP_PATTERNS + ERROR_COUNT
  |- 連線類 pattern -> 切 health-check（帶 service name）
  |- 資源類 pattern -> 本地處理（docker stats / df -h）
  |- 應用邏輯 pattern -> Step 4
Step 4: 追蹤因果鏈   -> 輸出 ROOT_CAUSE + CAUSAL_CHAIN
Step 5: 比對基線     -> 輸出 SEVERITY（突發 vs 慢性）
  v
回報 -> 建議下一步：
  |- 已修復 -> /post-mortem
  |- 需要改 code -> 帶著 ROOT_CAUSE 回到開發流程
  |- 需要改 infra -> 帶著 CAUSAL_CHAIN 切 docker-k8s 或 health-check
```

### 1. 確定時間範圍 -> 輸出 `TIME_RANGE` + `SOURCE`

從 context 推斷或問使用者：

- 事件發生的大概時間
- 正常運作的最後已知時間
- 時區（預設 UTC+8）

**從 health-check / docker-k8s 進來時**：`TIME_RANGE` 和 `SOURCE`（container/service name）已確定，跳到 Step 2。

### 2. 取得相關日誌 -> 輸出 `RAW_LOGS`（不超過 200 行）

```bash
# Docker -- 限定時間範圍 + 行數
docker logs --since "$TIME_START" --until "$TIME_END" $SOURCE 2>&1 | tail -100

# 只看 stderr（錯誤流）
docker logs $SOURCE 2>&1 1>/dev/null | tail -50

# journalctl -- 系統服務
journalctl -u $SOURCE --since "10 minutes ago" --no-pager | tail -100

# K8s pod
kubectl logs --tail=100 $POD -n $NS
```

**判定：有沒有拿到 log？**
- 空的 -> 容器可能已重啟（`docker logs --previous` 或 `kubectl logs --previous`）
- 權限不足 -> 提示使用者需要的權限
- 有內容 -> 帶 `RAW_LOGS` 進 Step 3

### 3. 過濾 signal -> 輸出 `TOP_PATTERNS` + `ERROR_COUNT`

```bash
# 錯誤計數 -- 先看全貌
echo "$RAW_LOGS" | grep -ciE "error|fatal|panic|exception|critical"

# 錯誤分類 -- 哪類錯最多
echo "$RAW_LOGS" | grep -iE "error|fatal|exception" | sed 's/[0-9]/#/g' | sort | uniq -c | sort -rn | head -10

# 時間分布 -- 突然爆發還是持續發生
echo "$RAW_LOGS" | grep -i error | awk '{print $1}' | cut -d: -f1,2 | uniq -c
```

**分流（根據 TOP_PATTERNS 分類）：**

| Pattern 類型 | 範例 | 分流到 |
|-------------|------|--------|
| 連線類 | `ECONNREFUSED`, `ETIMEDOUT`, `MongoNetworkError` | 切 `health-check` Step 1（帶目標 host:port） |
| 資源類 | `ENOMEM`, `OOMKilled`, `ENOSPC`, `EMFILE` | 本地處理：`docker stats` / `df -h` / 調 limits |
| 應用邏輯類 | `TypeError`, `ValidationError`, stack trace | 進 Step 4 追因果鏈 |
| 認證類 | `401`, `403`, `AuthenticationError` | 檢查 token/secret 設定 |
| 無明顯 error | 錯誤數 = 0 | 擴大時間範圍重試，或查 system log（`dmesg`, `journalctl -k`） |

### 4. 追蹤因果鏈 -> 輸出 `ROOT_CAUSE` + `CAUSAL_CHAIN`

```bash
# 取 top pattern 的前後 context
echo "$RAW_LOGS" | grep -B5 -A5 "{top-pattern}" | head -50

# 追蹤特定 request ID / trace ID
echo "$RAW_LOGS" | grep "{request-id}"
```

**判定：能不能建立因果鏈？**
- 能 -> `CAUSAL_CHAIN = A -> B -> C`，`ROOT_CAUSE = C`
- 不能（log 資訊不夠）-> 需要更多 log source：
  - 同一 namespace 的其他 pod？（`kubectl logs` 其他 container）
  - 上游服務的 log？（用 `ECONNREFUSED` 的目標 host 找對應 container）
  - system log？（`dmesg | tail -20`）

### 5. 比對基線 -> 輸出 `SEVERITY`

```bash
# 正常時段的錯誤率
docker logs --since "$BASELINE_START" --until "$BASELINE_END" $SOURCE 2>&1 | grep -c -i error

# 異常時段的錯誤率
echo $ERROR_COUNT
```

**判定：**
- 異常時段 >> 正常時段 -> `SEVERITY=突發`（可能跟 deploy/config change 有關）
- 一直都有 -> `SEVERITY=慢性`（tech debt / 需要長期修復）
- 正常時段也沒有 baseline -> 跳過，直接回報

## 回報格式 + 下一步

```text
[Log Analysis] {service-name} | {TIME_RANGE}

問題：{一句話描述}
錯誤數量：{ERROR_COUNT} errors in {duration}
Top Pattern：{TOP_PATTERNS[0]}
因果鏈：{CAUSAL_CHAIN}
嚴重度：{SEVERITY}
根因：{ROOT_CAUSE}

下一步：
  -> {具體行動，帶入對應 skill 和變數}
```

**回報後的分流：**
- 問題已修復 -> 建議 `/post-mortem`（帶入 ROOT_CAUSE + CAUSAL_CHAIN + TIME_RANGE）
- 需要改 code -> 帶 ROOT_CAUSE 回開發流程（使用者決定）
- 需要改 infra -> 切 `docker-k8s`（K8s 問題）或 `health-check`（連線問題），帶入已確認的變數
- 需要看更多 log -> 回 Step 2 換 SOURCE

## 與其他 SRE skill 的銜接

- 從 `health-check` 進來時：`TIME_RANGE` + `SOURCE` 已確定，跳到 Step 2
- 從 `docker-k8s` 進來時：`NS` + `POD` 已確定，轉為 `SOURCE`，跳到 Step 2
- 從 `issue-ops` Stage 4a 進來時：`BRANCH` + run ID + failed job 已確定，`TIME_RANGE` = CI run 時間，跳到 Step 2
- 分流到 `health-check` 時：帶入從 log 中提取的目標 host:port
- 結束後到 `/post-mortem`：帶入 ROOT_CAUSE + CAUSAL_CHAIN + TIME_RANGE

## 規則

1. 不要一次撈超過 200 行 -- 先統計再細看
2. 先看 pattern（`sort | uniq -c`）再看個案
3. 不要看到第一個 error 就下結論 -- 它可能是結果不是原因
4. 區分 application log 和 system log -- 問題可能在不同層
5. 時間戳很重要 -- 沒有時間的 log 分析是猜測
