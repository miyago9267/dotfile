---
spec: astra-agent-identity
batch: 1
created: 2026-09-15
---

# Tasks: Astra 單一 Agent 身份與舊 runtime 相容

> Spec: `docs/specs/astra-agent-identity/SPEC.md`
> Batch: 1

## 前置條件

- [x] Miyago 已明確授權本次規則重構與 Astra identity 設計
- [x] 相關 canonical source、runtime adapters 與 generated output 已定位

## 實作步驟

- [x] Step 1: 將 shared contract 與 runtime metadata 統一為 Astra identity
- [x] Step 2: 收斂 Claude、Codex、Gemini、Zed 的 Skill trigger 與 duplicate rules
- [x] Step 3: 建立 explicit Astra adapter、allowlist 與 isolated setup script
- [x] Step 4: 重新生成 runtime outputs 並完成 compatibility/static verification

## 驗證

- [x] 所有步驟完成
- [x] 測試通過（見 TESTS.md）
- [x] 文件更新

## 備註

舊 plugin、OpenCode agent 與 runtime IDs 保留；身份名稱的相容層不等於第二個 persona。
