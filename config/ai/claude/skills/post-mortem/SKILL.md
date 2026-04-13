---
name: post-mortem
description: "事後分析報告產生器 -- 事故處理完後，引導產出結構化 post-mortem 報告（timeline、root cause、action items）。"
user-invocable: true
---

# /post-mortem [incident-name]

事故處理完成後，產出結構化的事後分析報告。

## 資料收集

產出報告前，依序收集以下資訊（問使用者或從 context 推斷）：

1. **事故概述** -- 什麼壞了、影響範圍、持續時間
2. **偵測方式** -- 怎麼發現的（monitoring、使用者回報、CI 失敗）
3. **Timeline** -- 從偵測到修復的關鍵時間點
4. **根因分析** -- 直接原因 + 根本原因（用 5 Whys 追問）
5. **修復措施** -- 做了什麼止血、做了什麼永久修復
6. **影響評估** -- 影響的使用者數、資料損失、SLA 影響

## 報告模板

```markdown
# Post-Mortem: {incident-name}

**日期：** YYYY-MM-DD
**嚴重度：** P0 / P1 / P2 / P3
**持續時間：** {偵測到修復的時間}
**影響範圍：** {受影響的服務/使用者}

## 概述

一段話描述發生了什麼。

## Timeline (UTC+8)

| 時間 | 事件 |
|------|------|
| HH:MM | 偵測到異常 |
| HH:MM | 開始調查 |
| HH:MM | 定位根因 |
| HH:MM | 部署修復 |
| HH:MM | 確認恢復 |

## 根因分析

### 直接原因

{觸發事故的直接因素}

### 5 Whys

1. 為什麼 {症狀}？ -- 因為 {原因 1}
2. 為什麼 {原因 1}？ -- 因為 {原因 2}
3. 為什麼 {原因 2}？ -- 因為 {原因 3}
4. 為什麼 {原因 3}？ -- 因為 {原因 4}
5. 為什麼 {原因 4}？ -- 因為 {根本原因}

### 根本原因

{一句話總結根本原因}

## 修復措施

### 止血（已完成）

- {緊急修復 1}
- {緊急修復 2}

### 永久修復（待完成）

- [ ] {永久修復 1} -- owner: {誰} -- deadline: {何時}
- [ ] {永久修復 2} -- owner: {誰} -- deadline: {何時}

## 預防措施

- [ ] {防止再次發生的措施} -- owner: {誰}
- [ ] {改善偵測速度的措施} -- owner: {誰}

## 教訓

### 做得好的

- {值得保留的做法}

### 需改進的

- {下次應該避免的做法}
```

## 存放位置

報告存到 `docs/post-mortems/YYYY-MM-DD-{incident-name}.md`，進 git commit。

## 與其他 SRE skill 的銜接

- 從 `health-check` 或 `log-analysis` 完成後進來時，從當前 session 排查記錄自動提取 timeline 和根因
- 從 `issue-ops` Stage 4c 進來時：`ISSUE` + 修復 timeline 已確定，用於報告的概述和 timeline 段落
- 報告中的 timeline 和根因應引用排查過程中實際跑過的指令和結果
- 報告完成後，用 `learn` 提取值得記錄的 pattern

## 規則

1. 不追究個人責任，聚焦系統性問題
2. Timeline 必須用具體時間，不用「大約」「左右」
3. Action items 必須有 owner 和 deadline
4. 根因分析不能停在表面（「部署出錯」不是根因，「沒有 pre-deploy smoke test」才是）
