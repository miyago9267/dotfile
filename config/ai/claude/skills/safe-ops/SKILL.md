---
name: safe-ops
description: 危險或不可逆操作前的 safety confirmation；普通 local edit、Git read 與測試不觸發額外確認。
when_to_use: "執行 destructive、privileged、production/shared、credential、external 或 irreversible 操作前。"
tags: [safety, destructive, privilege, production, credential]
effort: low
shell: none
runtime-scope: shared-core
alwaysApply: true
---

# Safe Ops

以下操作在執行前必須說明 target、blast radius、rollback，並取得 Miyago 明確確認：

- `rm -rf` 非 `/tmp/` 目標、`git reset --hard`、`git clean -fd`、force push、遠端分支刪除。
- `DROP`、無條件大量 `DELETE/UPDATE`、destructive schema migration。
- production/shared infrastructure、cloud resource、IAM、DNS、namespace/deployment deletion。
- sudo/root、credentials、`.env` 或其他 secret-bearing file；外部、付費、發布或不可逆操作。

普通 repo code/config/docs edit、`git status/diff/add/commit`、lint/test/build 與可逆的
local generation 不需要額外確認。不要用 `docker run` 手動建立 CI/CD 管理的 container。
遇到不確定 target，先用 read-only check；確認 alias 與 environment 後才執行寫入。
