---
name: safe-ops
description: "重大、破壞性、特權、production、credential 或外部不可逆操作前，要求確認。"
when_to_use: "每次即將執行符合安全邊界的高影響操作前套用；一般 local edit 不觸發確認。"
tags: [safety, destructive, privileged, production, credentials]
effort: low
shell: required
runtime-scope: shared-core
alwaysApply: true
---

# safe-ops -- 安全邊界

## 執行前必須確認

執行以下操作前，說明 target、blast radius、rollback，並取得 Miyago 明確確認：

- `rm -rf` 非 `/tmp/` 或目前開發 project 的目錄、資料庫 destructive command。
- production/shared infrastructure、cloud resource、IAM、DNS 或 Kubernetes resource
  deletion。
- `sudo`、root、credential、`.env` 或其他 secret-bearing file 操作。
- force push、遠端 branch deletion、付費、發布或其他不可逆 external action。

## 可直接執行

普通 local code/config/docs edit、`git status/diff/add/commit`、lint/test/build 與 local
generation 不需要額外確認。不要用 `docker run` 手動建立 CI/CD 管理的 container。

遇到不確定 target，先做 read-only check；確認 alias、environment 與 scope 後再執行寫入。

## Hard constraints

- 不擅自使用 `sudo` 或 root；需要時交回 Miyago。
- 不把 secret 放進 chat、logs、files、arguments 或 tool output。
- 覆寫重要 legacy file 前先採用可恢復的備份方式。
