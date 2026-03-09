---
id: spec-path-config-normalization
title: Zsh PATH 規格統一
status: completed
created: 2026-03-09
updated: 2026-03-09
author: Miyago
approved_by:
tags: [zsh, path, dotfiles]
priority: medium
---

# Zsh PATH 規格統一

## Requirements
- VS Code CLI 路徑需改成變數化，且只有在實際安裝存在時才加入 `PATH`。
- `.zshrc` 與 `.zshrc.d` 中的 PATH 規則應採用一致風格：以變數表達路徑、先檢查存在，再避免重複加入。
- 已拆成 snippet 管理的工具設定，不再在 `.zshrc` 保留重複 PATH/completion 載入邏輯。
- 調整後需通過 zsh 語法檢查，且實際載入時仍能找到 `code`、`pnpm` 與 OpenClaw completion。

## Architecture / Plan
### Decisions
- **Decision:** 新增共用 helper snippet `00_path_helpers.zsh`，提供 PATH prepend 與目錄存在檢查。
  - **Reason:** 讓各個 `.zshrc.d/*.zsh` 不必重複撰寫 `case ":$PATH:"` 模板，後續新增工具路徑時只需沿用同一規格。
  - **By:** Miyago (2026-03-09)
- **Decision:** `pnpm` 同時支援 `~/.local/share/pnpm` 與 `~/Library/pnpm`，並以實際存在的路徑決定 `PNPM_HOME`。
  - **Reason:** repo 舊設定與現有 snippet 使用的位置不同，保留兩者可避免清理時造成既有環境退化。
  - **By:** Miyago (2026-03-09)
- **Decision:** OpenClaw completion 改為 snippet 管理，優先讀固定 completion 檔，若不存在再 fallback 到 `openclaw completion --shell zsh`。
  - **Reason:** 統一 completion 載入位置，同時保留原本動態產生 completion 的能力。
  - **By:** Miyago (2026-03-09)

## Tasks
- [x] Phase 1: 建立 PATH helper 並統一 `.zshrc.d` PATH 寫法。
- [x] Phase 2: 移除 `.zshrc` 內與 snippet 重複的 bun、nvm、pnpm、OpenClaw 載入。
- [x] Phase 3: 驗證 zsh 語法與實際 PATH/command 載入結果。

## Files
- `.zshrc` - 移除重複設定，保留早期 Homebrew PATH 修復並在 snippet 載入後清理 helper。
- `.zshrc.d/00_path_helpers.zsh` - 共用 PATH helper。
- `.zshrc.d/android.zsh` - Android SDK PATH 走共用 helper。
- `.zshrc.d/antigravity.zsh` - Antigravity PATH 改用變數與存在檢查。
- `.zshrc.d/bun.zsh` - bun PATH/completion 統一規格。
- `.zshrc.d/flutter.zsh` - Flutter PATH 走共用 helper。
- `.zshrc.d/fvm.zsh` - FVM 與 pub-cache PATH 走共用 helper。
- `.zshrc.d/gcc.zsh` - GCC PATH 改用變數與存在檢查。
- `.zshrc.d/go.zsh` - Go fallback PATH 走共用 helper。
- `.zshrc.d/openclaw.zsh` - OpenClaw completion snippet。
- `.zshrc.d/php83.zsh` - PHP 8.3 bin/sbin PATH 統一規格。
- `.zshrc.d/pnpm.zsh` - pnpm 多路徑支援與 `PNPM_HOME` 統一。
- `.zshrc.d/python.zsh` - pyenv 與 `~/.local/bin` PATH 走共用 helper。
- `.zshrc.d/system_path.zsh` - 系統 PATH 走共用 helper。
- `.zshrc.d/utils.zsh` - utils PATH 走共用 helper。
- `.zshrc.d/vscode_remote_cli.zsh` - VS Code 本機 CLI 與 remote CLI PATH 驗證邏輯。
- `.zshrc.d/zplug.zsh` - zplug PATH 走共用 helper。

## Notes
- 驗證指令：
  - `zsh -n .zshrc .zshrc.d/*.zsh`
  - `zsh -fc 'for f in .zshrc.d/*.zsh; do . "$f"; done; print -r -- "$PATH"'`
