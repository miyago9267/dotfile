# docker-k8s — 場景手冊與 Docker 操作

## K8s 常見排查場景

### Pod 起不來

```bash
# 1. 看狀態
kubectl get pods -n {ns} | grep {name}

# 2. 看 events（通常有答案）
kubectl describe pod {pod} -n {ns} | grep -A20 "Events:"

# 3. 常見原因
# - ImagePullBackOff -> image 名稱/tag 錯，或 registry 認證問題
# - CrashLoopBackOff -> 應用 crash，看 logs --previous
# - Pending -> 資源不足或 node selector 配不上
# - ContainerCreating 卡住 -> volume mount 或 secret 問題
```

### 服務連不到

```bash
# 1. Service 存在嗎？
kubectl get svc -n {ns}

# 2. Endpoints 有東西嗎？（空的 = selector 沒配對到 pod）
kubectl get endpoints {svc} -n {ns}

# 3. 從 pod 內部測試
kubectl exec -it {pod} -n {ns} -- curl -sf http://{svc}:{port}/health

# 4. Ingress 設定
kubectl get ingress -n {ns}
kubectl describe ingress {name} -n {ns}
```

### Rollout 問題

```bash
# 部署狀態
kubectl rollout status deploy/{name} -n {ns}

# 部署歷史
kubectl rollout history deploy/{name} -n {ns}

# 回滾
kubectl rollout undo deploy/{name} -n {ns}
```

## Docker 操作指引

### 探索流程

```bash
# 看所有 container（含停止的）
docker ps -a

# 看 compose 管理的服務
docker compose ps

# 看 network
docker network ls
docker network inspect {network}

# 看 volume
docker volume ls
```

### 常用操作

```bash
# 建構
docker build -t {name}:{tag} .

# 日誌（限定行數）
docker logs --tail 50 {container}

# 進入 container
docker exec -it {container} /bin/sh

# 資源使用
docker stats --no-stream

# 清理
docker system prune -af
```

### Docker Compose

```bash
# 啟動
docker compose up -d

# 查看狀態
docker compose ps

# 重建特定服務
docker compose up -d --build {service}

# 看日誌
docker compose logs --tail 50 {service}
```

### Dockerfile 撰寫原則

- Multi-stage build 減少 image 大小
- 基礎 image 不用 `latest`，明確指定版本
- Node/TS 用 `node:xx-alpine`，Go 用 `golang:xx-alpine` build + `distroless` run
- 不常變的層（依賴安裝）放前面
- 加 `.dockerignore`
