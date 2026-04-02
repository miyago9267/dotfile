---
name: health-check
description: "服務連線與健康度檢查 -- 觸發：使用者提到連不上、timeout、health、服務狀態、連線問題。系統性檢查服務依賴，而非亂猜原因。"
alwaysApply: false
---

# 服務健康度檢查

當使用者遇到服務連線問題時，用系統性方法逐層排查，不要跳到結論。

## 觸發條件

- 使用者提到「連不上」「timeout」「connection refused」「502」「503」
- 使用者問服務狀態、健康檢查
- 部署後確認服務是否正常

## 排查順序（由外到內，每步有判定 + 分流）

```text
Step 1: DNS / 網路層 -> OK? 往下 / FAIL? -> 網路問題，查 firewall/DNS
Step 2: 服務進程     -> OK? 往下 / FAIL? -> 進程沒跑，查 docker/systemd
Step 3: 應用層 HTTP  -> OK? 往下 / FAIL? -> 應用 crash，切 log-analysis
Step 4: 資料庫連線   -> OK? 往下 / FAIL? -> DB 問題，查連線池/認證
Step 5: 反向代理     -> OK? 往下 / FAIL? -> proxy 設定錯，查 nginx/ingress
Step 6: TLS          -> OK? 全部正常 / FAIL? -> 憑證問題
                                    |
                             問題定位後 -> /post-mortem
```

不要跳步驟。每一步確認 OK 才往下。FAIL 就停在該層處理。

### 1. DNS / 網路層 -> 判定：能不能 resolve + 能不能 TCP 連上

```bash
# 域名解析
dig +short {domain} || nslookup {domain}

# 端口連通
nc -zv {host} {port} -w 5

# 從容器內測試（Docker 場景）
docker exec {container} curl -sf http://localhost:{port}/health
```

**FAIL 分流：**
- `dig` 無結果 -> DNS 問題（檢查 /etc/resolv.conf、DNS server、域名是否正確）
- `nc` timeout -> 防火牆/安全群組擋住（檢查 iptables、cloud security group）
- `nc` refused -> port 沒開 -> 往 Step 2 確認進程

**OK -> 帶著確認的 `HOST:PORT` 進入 Step 2**

### 2. 服務進程 -> 判定：進程在不在跑、有沒有 restart loop

```bash
# 容器狀態
docker ps --filter "name={service}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 最近日誌（只看最後 20 行）
docker logs --tail 20 {container} 2>&1

# 進程是否在跑（非 Docker）
pgrep -af {process-name}
```

**FAIL 分流：**
- Container 不存在 -> `docker ps -a` 看是被刪了還是從沒建
- Status = `Restarting` / restart count 高 -> CrashLoop，切 `log-analysis` 看 crash 原因
- Status = `Exited` -> `docker logs` 看最後輸出，可能是啟動失敗

**OK -> 帶著確認的 `CONTAINER` 進入 Step 3**

### 3. 應用層 Health Endpoint -> 判定：HTTP 回應碼 + 回應時間

```bash
# HTTP health check（同時看 status code 和延遲）
curl -sf -o /dev/null -w "%{http_code} %{time_total}s" http://{host}:{port}/health

# 帶 timeout
curl -sf --max-time 5 http://{host}:{port}/health
```

**FAIL 分流：**
- `000` / connection refused -> 進程跑了但沒 listen（回 Step 2 看 port binding）
- `500` / `502` / `503` -> 應用內部錯誤，切 `log-analysis`（帶入 container + 時間範圍）
- 回應時間 > 5s -> 效能問題（`docker stats` 看 CPU/Memory，再查應用層）

**OK -> 帶著確認的 `ENDPOINT` 進入 Step 4**

### 4. 資料庫連線 -> 判定：DB 能不能 ping、連線池是否健康

**MongoDB：**

```bash
# 從 host
mongosh --eval "db.runCommand({ping: 1})" {connection-string} --quiet

# 從容器內
docker exec {mongo-container} mongosh --eval "db.runCommand({ping: 1})" --quiet

# 連線數
mongosh --eval "db.serverStatus().connections" {connection-string} --quiet
```

**通用 TCP 測試：**

```bash
nc -zv {db-host} {db-port} -w 5
```

**FAIL 分流：**
- `nc` 連不上 -> DB 進程沒跑（`docker ps` 查 DB container）
- ping 失敗 + `MongoServerError: Authentication` -> 認證問題（檢查 connection string 的 user/password）
- 連線數接近上限 -> 連線池洩漏，切 `log-analysis` 查應用端是否正確關閉連線

**OK -> 帶著確認的 `DB_STATUS=healthy` 進入 Step 5**

### 5. 反向代理 / Load Balancer -> 判定：config 語法 + upstream 連通

```bash
# Nginx config 語法檢查
nginx -t

# 上游狀態
curl -sf http://localhost/nginx_status 2>/dev/null
```

**FAIL 分流：**
- `nginx -t` 失敗 -> config 語法錯（看錯誤訊息修）
- upstream 回 502 -> backend 掛了（回 Step 2-3 檢查 backend 進程）
- K8s 環境 -> `kubectl get ingress -n $NS` + `kubectl describe ingress` 查路由規則

**OK -> 帶著確認的 `PROXY_STATUS=healthy` 進入 Step 6**

### 6. TLS / Certificate -> 判定：憑證有效 + 未過期

```bash
# 檢查憑證到期
echo | openssl s_client -connect {host}:443 -servername {host} 2>/dev/null | openssl x509 -noout -dates

# 剩餘天數（macOS）
echo | openssl s_client -connect {host}:443 -servername {host} 2>/dev/null | openssl x509 -noout -enddate
```

**FAIL 分流：**
- `SSL routines` 錯誤 -> 憑證不匹配或協議版本問題
- 過期 < 7 天 -> 緊急 renew（Let's Encrypt: `certbot renew`，K8s: 檢查 cert-manager）
- 過期 < 30 天 -> 排入 action items

**全部 OK -> 回報：所有層檢查通過，問題可能在應用邏輯層，切 `log-analysis` 深入查**

## 常見問題速查

| 症狀 | 可能原因 | 檢查指令 |
|------|---------|---------|
| Connection refused | 服務沒跑 / port 錯 | `docker ps`, `nc -zv` |
| Connection timeout | 防火牆 / 安全群組 | `nc -zv -w 5`, 檢查 firewall rules |
| 502 Bad Gateway | upstream 掛了 | `docker logs`, `curl health` |
| 503 Service Unavailable | 服務過載 / 維護中 | `docker stats`, 應用日誌 |
| SSL handshake failure | 憑證問題 | `openssl s_client` |
| ECONNRESET | 服務 crash / OOM | `docker logs`, `dmesg` |
| MongoServerError | 認證失敗 / 連線池滿 | `mongosh ping`, 檢查 connection string |

## 與其他 SRE skill 的銜接

- 排查過程中需要分析日誌 -> 切換到 `log-analysis` 的方法論（先統計 pattern，不要 dump 全部）
- 問題定位並修復後 -> 建議使用者用 `/post-mortem` 產出事後分析報告
- 回報格式沿用 `log-analysis` 的結構：`[Health Check] {service} | {症狀} -> {根因} -> {修復}`

## 規則

1. 按順序排查，不要跳到「可能是 X」的猜測
2. 每一步都用指令驗證，不要用推理代替實測
3. Docker 環境要區分 host 網路和 container 網路
4. 不要在不確定的情況下重啟服務 -- 先收集完證據
