---
name: docker-k8s
description: Docker 與 Kubernetes 開發指引與常用操作。使用者觸發。
user-invocable: true
---

# /docker-k8s

## Docker 最佳實踐

### Dockerfile 撰寫原則

- 使用 multi-stage build 減少 image 大小
- 基礎 image 選擇：Go 用 `golang:x.xx-alpine` build + `scratch` 或 `distroless` run
- Node/TS 用 `node:xx-alpine`，Python 用 `python:x.xx-slim`
- 把不常變的層（依賴安裝）放前面，常變的層（複製原始碼）放後面
- 不要用 `latest` tag，明確指定版本
- 加 `.dockerignore` 排除不必要檔案

### 常用指令

```bash
# 建構
docker build -t <name>:<tag> .

# 執行
docker run -d --name <name> -p <host>:<container> <image>

# 查看
docker ps -a
docker logs -f <container>

# 清理
docker system prune -af
```

### Docker Compose

- 開發環境用 `compose.yaml`（v2 格式）
- 生產和開發分開：`compose.yaml` + `compose.dev.yaml`
- 環境變數用 `.env` 檔，不寫死在 compose 裡

## Kubernetes 常用操作

### kubectl 基本指令

```bash
# 查看資源
kubectl get pods -n <ns>
kubectl get svc -n <ns>
kubectl describe pod <name> -n <ns>

# 查看日誌
kubectl logs -f <pod> -n <ns>
kubectl logs -f <pod> -c <container> -n <ns>

# 進入 pod
kubectl exec -it <pod> -n <ns> -- /bin/sh

# 套用設定
kubectl apply -f <file>.yaml
kubectl apply -k <kustomize-dir>

# 偵錯
kubectl get events -n <ns> --sort-by=.lastTimestamp
kubectl top pods -n <ns>
```

### YAML 撰寫原則

- 使用 Kustomize 管理環境差異（base + overlays）
- Secret 不放在 git 裡，用 External Secrets 或 Sealed Secrets
- Resource limits/requests 一律設定
- 使用 `readinessProbe` 和 `livenessProbe`
- Label 統一格式：`app.kubernetes.io/name`、`app.kubernetes.io/component`
