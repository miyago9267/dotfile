---
spec: sre-locate
created: 2026-05-12
---

# Progress: SRE Locate

> Spec: `docs/specs/sre-locate/SPEC.md`

## Phase 1: locate.sh + 基本平行掃描

> Status: completed

- 目標：能用一個 keyword 平行掃 5 cluster + 3 project，輸出彙整結果
- Batch 1: 骨架 + 平行掃描 + 結果彙整 + skill SKILL.md

## Phase 2: 寫操作護欄 hook（嚴格三層）

> Status: completed

- 目標：kubectl / gcloud 寫操作分 Tier 1/2/3 護欄，CI caller 白名單
- Batch: ops-write-guard.sh + settings.json 註冊 + 三層各自 case 測試

## Phase 3: Inventory cache（TTL 6h）

> Status: completed

- 目標：service / deployment 反向索引快取，加速二次定位
- Batch: inventory-refresh.sh + locate.sh 讀 cache

## Phase 4: SSH VM 來源整合（R7）

> Status: completed

- 目標：從 ssh config 取 host 清單，平行 SSH read-only 查詢，併入 locate 結果

## Phase 5: 整合既有 skill

> Status: completed (文件層)

- 目標：locate 命中後可串接 log-analysis / health-check / post-mortem
- 實作：SKILL.md 的「與其他 skill 銜接」章節已寫；無新增程式碼

---

## Completed Phases

<!-- Phase 完成後封存到 archive/ -->
