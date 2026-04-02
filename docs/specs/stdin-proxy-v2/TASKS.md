---
spec: stdin-proxy-v2
batch: 1
created: 2026-04-02
---

# Tasks: stdin proxy v2

> Spec: `docs/specs/stdin-proxy-v2/SPEC.md`
> Batch: 1 (Phase 1 + Phase 2)

## 前置條件

- [x] 確認 spec 已獲 Miyago 核准

## Phase 1: PreToolUse auto-yes hook

- [x] Step 1: 建立 `claude/hooks/auto-yes.sh`，偵測 Bash 命令並自動加 non-interactive flag
  - apt install/upgrade (無 -y) → 加 `-y`
  - apt-get install/upgrade (無 -y) → 加 `-y`
  - npm init (無 -y) → 加 `-y`
  - 排除危險命令：`apt remove`, `apt purge`, `apt autoremove` 不自動加 -y
- [x] Step 2: 在 settings.json 的 PreToolUse hooks 註冊 auto-yes.sh
- [x] Step 3: 手動測試 -- 6 case 全通過
  - `sudo apt install nginx` → `sudo apt install -y nginx`
  - `apt install -y nginx` → 不改（已有 -y）
  - `apt remove nginx` → 不改（危險命令）
  - `npm init` → `npm init -y`
  - `npm init -y` → 不改（已有 -y）
  - `sudo apt-get upgrade` → `sudo apt-get upgrade -y`

## Phase 2: ask-tty skill 流程優化

- [x] Step 4: 更新 `claude/skills/ask-tty/SKILL.md`
  - 去掉 Telegram 依賴，純本地 file IPC
  - 加入 background 執行 + 先通知的三步流程
  - 加入判斷順序圖（auto-yes → ask-tty → ! fallback）
- [x] Step 5: 確認 tty-respond hook 的時序 -- 實測通過，tty:hello 正確送達 background ask-tty

## 驗證

- [x] auto-yes hook 正確改寫 `apt install nginx` → `apt install -y nginx`
- [x] auto-yes hook 不改寫 `apt remove nginx`（危險命令）
- [x] auto-yes hook 不改寫已有 `-y` 的命令（不重複加）
- [x] ask-tty background 流程中，使用者能在同視窗用 tty: 回覆

## 備註

<!-- Batch 完成後用 spec-archive.sh tasks stdin-proxy-v2 封存 -->
