---
name: docker-k8s
description: "Docker & Kubernetes ops guide -- triggers: k8s, kubectl, pod, container, deploy, namespace. Explore context before acting; no blind commands."
alwaysApply: false
when_to_use: "docker/k8s/kubectl/pod/deploy/namespace tasks that need cluster or container context discovery first."
tags: [docker, kubernetes, k8s, pod, deploy, namespace]
effort: medium
shell: required
runtime-scope: claude-native
---

# Docker 與 Kubernetes 操作指引

## 核心原則：先探索，再行動

不要直接跑 `kubectl get pods` 然後說找不到。每次接觸 k8s 任務時，先走探索流程。

## K8s 探索流程（每步輸出餵給下一步）

```text
Step 0: kubectl 可用嗎？
  |  輸出：kubectl path
  v
Step 1: 有哪些 context？ -> 選定 CONTEXT
  |  輸出：CONTEXT={chosen-context}
  v
Step 2: 這個 cluster 有哪些 namespace？ -> 選定 NS
  |  輸出：NS={chosen-namespace}
  v
Step 3: 這個 namespace 裡有什麼資源？ -> 選定 TARGET
  |  輸出：TARGET={resource-type}/{resource-name}
  v
Step 4: 定位目標 pod/deploy -> 選定 POD
  |  輸出：POD={pod-name}
  v
Step 5: 深入檢查 POD 的 describe / logs / events
```

### 0. 確認 kubectl 可用

```bash
kubectl version --client --short 2>/dev/null || echo "kubectl not found"
```

### 1. 查看所有 context -> 輸出 `CONTEXT`

```bash
kubectl config get-contexts -o name
```

- 輸出會列出所有可用 context
- 從中選定目標：`CONTEXT={context-name}`
- 如果當前 context（`kubectl config current-context`）不是目標，先切換：

```bash
kubectl config use-context $CONTEXT
```

### 2. 列出 namespace -> 輸出 `NS`

```bash
kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers
```

- 從輸出中選定目標：`NS={namespace}`
- 不要假設是 `default`。如果使用者提到了服務名稱，用它 grep namespace 列表
- 不確定時，列出所有 namespace 的 deployment 找目標：

```bash
kubectl get deploy -A | grep -v '^kube-'
```

- 要深入排查的目標分散在多個 namespace 時，用平行 Agents 各查一個，別逐一串行；Step 0-5 主流程因前一步輸出餵下一步仍維持序列。

### 3. 掃描 namespace -> 輸出 `TARGET`

```bash
kubectl get all -n $NS
```

- 從輸出中識別目標資源：`TARGET=deployment/my-app` 或 `TARGET=statefulset/my-db`
- `get all` 不包含 configmap、secret、ingress，需要時補查：

```bash
kubectl get configmap,secret,ingress -n $NS
```

### 4. 定位 pod -> 輸出 `POD`

```bash
# 從 deployment 找到它管理的 pods
kubectl get pods -n $NS -l app=$(kubectl get $TARGET -n $NS -o jsonpath='{.spec.selector.matchLabels.app}') --no-headers
```

- 從輸出中選定：`POD={pod-name}`
- 如果 label 找不到，用名稱 pattern：

```bash
kubectl get pods -n $NS | grep {keyword}
```

### 5. 深入檢查（用 `NS` + `POD`）-> 輸出 `SYMPTOM` -> 分流到對應 skill

```bash
# Pod 詳細狀態（含 events、restart reason）
kubectl describe pod $POD -n $NS

# 最近日誌
kubectl logs --tail=50 $POD -n $NS

# 如果 pod 有多個 container
kubectl logs --tail=50 $POD -c {container} -n $NS

# 之前 crash 的 container 日誌
kubectl logs --previous $POD -n $NS

# 資源使用量
kubectl top pods -n $NS

# 最近 events（排序）
kubectl get events -n $NS --sort-by=.lastTimestamp | tail -20
```

從 Step 5 的輸出判斷 `SYMPTOM`，分流到對應 skill：

```text
SYMPTOM 分流：
  |- 日誌中有 error pattern（大量重複錯誤、crash log）
  |    -> log-analysis（帶入 NS + POD + 時間範圍）
  |
  |- 連線問題（ECONNREFUSED、timeout、endpoints 為空）
  |    -> health-check（從 Step 3「應用層」開始，帶入 NS + service name）
  |
  |- Pod 狀態異常（CrashLoopBackOff、OOMKilled、Pending、ImagePullBackOff）
  |    -> 讀 playbook.md「K8s 常見排查場景」對應段落
  |
  |- 問題已解決
  |    -> 建議使用者 /post-mortem 記錄
```

## 場景手冊與 Docker 操作

K8s 常見排查場景（Pod 起不來 / 服務連不到 / Rollout）與 Docker 操作指引（探索、常用指令、Compose、Dockerfile 原則）在 [playbook.md](playbook.md)；定位到 SYMPTOM 後依需要讀。

## 與其他 SRE skill 的銜接

- 排查中發現連線問題 -> 切到 `health-check`（按順序排查，不亂猜）
- 需要看 container 日誌 -> 用 `log-analysis` 方法論（先統計 pattern 再細看）
- 事故處理完 -> `/post-mortem` 產出報告

## 規則

1. **先探索 context 和 namespace，再下任何操作指令**
2. 找不到資源時，先列出可用的 namespace 和資源，不要問使用者「你知道在哪裡嗎」
3. 不要假設 namespace 是 `default`
4. 不要在不確定的情況下 `kubectl delete` 或 `kubectl rollout undo` -- 先跟使用者確認
5. Docker 環境不要用 `docker run` 手動建 CI/CD 管理的 container -- push to main 讓 CI 處理
