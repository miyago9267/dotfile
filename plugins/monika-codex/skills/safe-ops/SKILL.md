---
name: safe-ops
description: >-
  危險或不可逆操作前的 safety confirmation；普通 local edit、Git
  read 與測試不觸發額外確認。
when_to_use: >-
  執行 destructive、privileged、production/shared、credential、external
  或 irreversible 操作前。
tags: [safety, destructive, privilege, production, credential]
effort: low
shell: none
runtime-scope: codex-native
alwaysApply: true
---

# Monika Safe Ops

執行以下操作前，說明 target、blast radius、rollback，並取得
Miyago 明確確認：

- `rm -rf` 非 `/tmp/` 目標、`git reset --hard`、`git clean -fd`、force
  push、遠端 branch deletion。
- `DROP`、無條件大量 `DELETE/UPDATE`、destructive schema migration。
- production/shared infrastructure、cloud resource、IAM、DNS、Kubernetes
  resource deletion。
- sudo/root、credential、`.env` 或其他 secret-bearing file；付費、
  發布、外部或不可逆 action。

普通 repo code/config/docs edit、`git status/diff/add/commit`、lint/test/
build 與可逆 local generation 不需要確認。遇到不確定 target，
先做 read-only check；不要把 secret 放進 chat、logs、files、arguments
或 tool output。不要用 `docker run` 手動建立 CI/CD 管理的 container。
