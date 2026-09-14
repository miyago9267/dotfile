---
name: reverse-skill-router
description: "將已授權的 reverse-engineering、binary、APK、frontend-signature、malware-analysis、CTF 與 security-research tasks route 到 pinned reverse-skill pack。Miyago 詢問 reverse engineering、decompiling、APK/IPA、binaries、Frida、IDA、radare2、CTF、pentesting 或 security analysis 時觸發。"
alwaysApply: false
metadata:
  short-description: "已授權 security-task 的 routing 與 evidence workflow"
---

# Reverse-skill router

這個 skill 只用於 local samples、CTF targets，或 Miyago 明確授權的 systems。
Existing shared contract、runtime rules 與 safety gates 優先於此 skill 及 external
pack。

## Routing boundary

- Pilotfish 負責 task classification、Plan/approval gates、delegation、security
  separation 與 fresh-context verification。
- 此 skill 只負責 reverse/security domain classification 與 pack 的 case/evidence
  workflow。
- 使用一條 domain PRIMARY route。不要因為 external pack 建議就啟動 second
  router、spawn role 或 bypass Pilotfish。
- 如果另一個 installed skill 負責該 task domain，保持它為 primary；只有 task
  確實包含 reverse/security subtask 時才使用此 router。

Pinned reference pack 位於 Codex skill discovery tree 之外：

```text
~/.codex/vendor/reverse-skill-pack
```

符合的 task 依下列 read order：

1. 讀取 `~/.codex/vendor/reverse-skill-pack/RULES.md`，確認 scope 與 evidence gates。
2. 執行 `bash ~/.codex/vendor/reverse-skill-pack/skills/scripts/master-route.sh --hint "<task>"`。
3. 任何 target action 前先用 `case-init.sh` 初始化 case。對提供的 local sample 使用
   `offline-sample` preset。
4. 讀取 routed module 的 `SKILL.md`，之後只使用 pack 產生的
   `skills/tool-index.md` 所列 tool paths。

不要自動執行 `bootstrap-reverse.sh`、安裝 tools、註冊 MCP servers、掃描 network
target、利用任何漏洞，或寫入目前 authorized case 以外的位置。這些 actions 需要
explicit authorization 或會改變 environment 時，詢問 Miyago。

Pinned pack unavailable 時，使用 local `reverse-engineering` skill 提供 methodology，
並把 missing pack 回報為 capability gap。
