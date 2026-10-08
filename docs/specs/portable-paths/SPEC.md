---
id: spec-portable-paths
title: 版控設定不寫死機器路徑（macOS / Linux / Windows 共用）
status: implemented-linux
created: 2026-10-08
updated: 2026-10-08
author: Miyago
tags: [dotfile, cross-platform, claude, gemini, opencode, shoal]
priority: high
---

# 版控設定不寫死機器路徑

## Background

Miyago 在 macOS、Linux、Windows 三邊共用同一個 dotfile repo。目前 repo 裡有
大量 `/Users/miyago/...` 絕對路徑，2026-10-08 在 Linux pull 之後實際壞掉的有：

- Claude `SessionStart` 的 herdr hook 找不到檔案（每次開 session 報錯）。
- shoal guard 的 hook command 指向不存在的路徑，要重跑 `install_hooks.py`
  才會修好，修好之後 repo 就髒了。
- 4 個 skill symlink 斷掉，`setup_claude.sh` 重建後 repo 也髒了。
- `gemini/hooks.json` 的 `agy-auto-update.sh` 與 `secret-guard-adapter.sh`
  指向不存在的路徑；後者是 secret guard，壞掉時不會有任何提示。

根因有三個，都在 dotfile 這一側：

1. `~/.claude/settings.json`、`~/.gemini/config/hooks.json` 是指回 repo 的
   symlink，第三方 installer（herdr、orca、shoal）回寫的絕對路徑直接進版控。
2. `~/.claude/skills` 整個目錄指回 repo，各工具丟進去的 symlink（絕對目標）
   也跟著被 commit。
3. 手寫設定直接用了 `/Users/miyago/...`。

成功條件：任一台機器 `git pull && bash setup.sh --config-only`（Windows 為
`setup.ps1 -ConfigOnly`）之後 hook 不報錯，且 `git status` 是乾淨的。

### 盤點（HEAD `cb2eb30`）

| 類別 | 檔案 | 寫入者 |
| --- | --- | --- |
| A. hook command | `config/ai/claude/settings.json`（shoal guard x2、herdr）、`config/ai/gemini/hooks.json`（agy-auto-update、herdr、orca x5、secret-guard-adapter） | shoal、herdr、orca、dotfile setup |
| B. 權限與目錄清單 | `claude/settings.json` 的 `additionalDirectories` x4 與一條 `Bash(...)`；`gemini/antigravity-cli/settings.json` 29 處 | 手寫與 runtime 回寫 |
| C. tracked symlink（絕對目標）11 個 | repo 內 4 個：`community-tech-brief`、`desktop-ops`、`jev-tools`、`knowledge-base-router`；repo 外 7 個：`jev-browser`、`jev-choice`、`jev-shadow-report`、`reticle-verify`、`experience-harvest`、`patina`、`sepia` | `setup_claude.sh`、`setup_jev.sh`、各工具 installer |
| D. 工具設定 | `opencode/opencode.json` x2、`opencode-harness/opencode.json` x3、`claude/remora-proxy/remora.config.toml`、`zsh/.zshrc.d/common.zsh`、`gemini/hooks/agy-auto-update.sh`、`ghostty/config` | 手寫 |
| E. agent 讀的文字 | `config/ai/runtime-bindings.yaml`（115 處）、`AGENT-ENTRY.md`、`codex/AGENTS.runtime.md`、`gemini/GEMINI.md` 與 generated 版本 | 手寫與 generator |
| F. 預設路徑假設 | shoal checkout 預設 `~/Project/Active/Forks/Fork-Remaster-code/shoal`，不存在時 setup 與 auto-update 靜默略過 | dotfile |

## Requirements (EARS)

- **R1**: The repo shall not contain `/Users/<name>`、`/home/<name>` 或
  `C:\Users\<name>` 於 A、B、D、E 類檔案；home 一律寫成 `~`、`$HOME` 或該工具
  自己的變數語法。
- **R2**: When a hook command 指向可能不存在的工具（herdr、orca、agy），the
  command shall 在檔案不存在時 exit 0 且不輸出。
- **R3**: The repo shall not track 絕對目標的 symlink。repo 內的 skill link 改為
  相對目標；指向 repo 外的 skill link 不進版控，由 setup 在來源存在時建立。
- **R4**: When 第三方 installer 把絕對路徑回寫進 tracked 檔案, the dotfile shall
  提供一支 normalizer 把它改回可攜形式，且重跑結果不變。
- **R5**: When commit 內含 R1 或 R3 禁止的內容, the pre-commit hook shall 擋下
  並印出檔案、行號與修正指令。
- **R6**: When `setup.sh --config-only` 在乾淨的 checkout 上跑完, `git status`
  shall 為乾淨（macOS、Linux 各驗一次；Windows 驗 `setup.ps1 -ConfigOnly`）。
- **R7**: If shoal checkout 不存在, then setup 與 `agent-stack-auto-update.sh`
  shall 印出一行明確訊息（缺少的路徑與 `SHOAL_ROOT` 用法），不靜默略過。
- **R8**: When shoal 的 `install_hooks.py` 把絕對路徑寫回 hook 設定, `--fix`
  shall 把它改回可攜形式，且不產生重複的 shoal entry。

## Non-goals

- 不把 `settings.json` 拆成 base 加 machine overlay 再產生（見方案 B）。
- 不處理只在單一平台使用的設定：`config/warp/*`（macOS）、
  `config/windows-terminal/*`（Windows）、`config/vscode/settings.json` 裡的
  平台專屬工具路徑。
- 不改歷史紀錄類檔案：`docs/`、`work/`、`*.before-*` 備份、
  `config/ai/memories/extensions/skysight/resources/*`。
- 不處理 `.claude/settings.local.json` 被版控這件事（見待決事項 3）。
- 不在這份 spec 解決 Windows 上 `python3` 指令不存在的問題；只記錄為風險。
- 不改 shoal repo（Miyago 2026-10-08 決定）。
- 不改 `config/ai/gemini/antigravity-cli/settings.json`：裡面有 `read_file`、
  `write_file` 的 deny 規則，agy 是否展開 `~` 尚未確認，改錯會讓 deny 靜默失效。

## Alternatives Considered

### 方案 A：tracked 檔案只放可攜形式，加 normalizer 與 guard（採用）

檔案結構不變，`settings.json` 繼續是 symlink，runtime 回寫照樣能 commit。
新增一支 normalizer 與一條 pre-commit 檢查。改動小，可逐檔 revert。

### 方案 B：tracked 只放 base，setup 產生各機器的 `settings.json`

機器差異完全不進 repo，但 `~/.claude/settings.json` 不再是 symlink：Claude
的 `/config`、權限核准、plugin 開關這些回寫會留在本機，要另外做「回收進
base」的流程。目前 repo 有「同步 runtime 回寫的設定」這類 commit，代表這條
回寫路徑是在用的，方案 B 會把它弄斷。不採用。

### 方案 C：每台機器把路徑修成自己的，標 `git update-index --skip-worktree`

不用改任何檔案，但 pull 遇到同檔變更就衝突，而且每台新機器都要手動設一次。
不採用。

## Rabbit Holes

1. normalizer 只動 `FIX_FILES` 裡 key 為 `command` 的字串，其他欄位不碰。
   比對的是 `/Users/<name>`、`/home/<name>`、`C:\Users\<name>` 前綴（不限當前
   `$HOME`，否則在 Linux 修不到 Mac 寫的路徑）。
2. 單引號包住的路徑（`bash '/Users/miyago/x'`）換成 `$HOME` 後要改成雙引號，
   否則變數不展開。
3. orca 在 `claude/settings.json` 寫的 hook 已經是 `${HOME-}` 形式，只有
   `gemini/hooks.json` 那 5 條是絕對路徑；不要去動前者。
4. `additionalDirectories` 與 agy 的 `command(...)`、`read_file(...)` 規則是否
   接受 `~`，要先實測再改，不要假設。
5. Windows 的 git symlink 需要 `core.symlinks=true` 與 Developer Mode；相對
   symlink 在沒開的機器會被 checkout 成文字檔。

## Architecture

```text
script/common/portable_paths.py
  --check     掃 tracked 檔案與 symlink，違規時 exit 1（給 pre-commit 與 CI 用）
  --fix       把當前 $HOME 前綴改寫成可攜形式（給 setup 與 auto-update 用）

呼叫點
  script/git-hooks/pre-commit              -> --check（只看 staged 檔案）
  script/common/update_config.sh 結尾       -> --fix
  claude/hooks/agent-stack-auto-update.sh  -> shoal 同步後 --fix
  script/common/check_agent_rule_sync.sh   -> --check
```

各類檔案的可攜寫法：

| 類別 | 寫法 |
| --- | --- |
| A. hook command | word 開頭用 `~`，雙引號內用 `$HOME`，單引號改雙引號；可選工具加 `[ -f "$f" ] \|\| exit 0` |
| B. Claude 權限 | `~/...`（實測通過才改） |
| C. repo 內 symlink | 相對目標，例如 `../../shared/skills/jev-tools` |
| C. repo 外 symlink | 加進 `.gitignore`，由 `setup_jev.sh` 等在來源存在時建立 |
| D. opencode | `{env:HOME}/...` |
| D. remora toml | 版控寫 `"~/..."`；`setup_claude.sh` 複製時展開成該機器的 home |
| D. shell script、zsh alias | `$HOME` |
| E. 文字與 yaml | `~/...`；`check_agent_rule_sync.sh` 的比對字串同步調整 |

## ADR

### ADR-1: 不拆 base 與 overlay

- 決策：採方案 A，tracked 檔案本身就是可攜的。
- 原因：保留 runtime 回寫可以直接 commit 的現有流程；減少一層產生步驟。

### ADR-2: 不改 shoal，由 dotfile 的 normalizer 收尾

- 決策：shoal 維持寫絕對路徑；`agent-stack-auto-update.sh` 與
  `update_config.sh` 在 shoal 安裝之後跑 `portable_paths.py --fix`。
- 原因：Miyago 決定這次只動 dotfile。shoal 用 `shoal_guard.py --host` 辨認自己
  的 entry，改成 `~/...` 之後仍認得，重裝只會覆寫同一條，不會多出重複的。
- 代價：每次 shoal 重裝都會先寫回絕對路徑再被改回來；兩個步驟之間 commit
  會被 pre-commit 擋下，跑一次 `--fix` 即可。

### ADR-3: repo 外的 skill link 不進版控

- 決策：7 個指向 repo 外的 skill link 從 index 移除並加進 `.gitignore`。
- 原因：它們的目標在另一個 repo 或工具的安裝目錄，每台機器位置與有無都不同，
  版控只會把某一台的狀態強加給其他台。

## 實作狀態（2026-10-08，Linux）

已完成並驗證：

- `script/common/portable_paths.py`（`--check`、`--fix`）與 17 個測試。
- A 類：`claude/settings.json`、`gemini/hooks.json` 全部 hook command；herdr
  兩條加上存在性防護。56 條 command 以 `/bin/sh -n` 檢查語法通過。
- B 類：`additionalDirectories` 改 `~/`（Claude Code 實際展開成功）；刪掉一條
  一次性的 `Bash(/bin/ls /Users/...)` allow 規則。
- C 類：4 個 shared skill link 改相對目標；7 個 repo 外 skill link 移出版控並
  加進 `.gitignore`，`setup_claude.sh` 在來源存在時建立、不存在時清掉斷掉的。
- D 類：opencode 兩份設定改 `{env:HOME}`（含 `setup_computer_use.sh` 的寫入
  邏輯）、remora、zsh alias、`agy-auto-update.sh`、ghostty。
- E 類：`runtime-bindings.yaml` 與各 agent 文字改 `~/`。
- pre-commit、`update_config.sh`、`check_agent_rule_sync.sh`、
  `agent-stack-auto-update.sh` 已接上；缺 shoal checkout 時會印訊息（R7）。
- R6：連跑兩次 `setup.sh --config-only`，`git status` 不變。
- R8：shoal 重裝後 `--fix`，兩個檔案與重裝前逐位元相同，shoal entry 各 2 條。

尚未驗證（這台機器沒有對應的工具）：

- opencode 是否如文件所述展開 `{env:HOME}`（Linux 沒裝 opencode）。
- ghostty 的 `background-image` 是否展開 `~/`。
- herdr、orca 在 Mac 重裝時會不會因為比對不到原字串而多加一條 entry。
- macOS 與 Windows 的 R6 實跑。

Mac pull 之後要跑一次 `bash setup.sh --config-only`：7 個 repo 外 skill link
會隨 pull 從工作區消失，由 setup 重建。

## Risks

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| herdr、orca 用字串比對找自己的 entry，改寫後重裝時多加一條重複的 | hook 重複執行 | Phase 1 在 Mac 重跑一次 herdr 與 orca 的安裝確認；會重複的 entry 列為例外，只加存在性防護 |
| Windows 沒開 symlink 支援 | 相對 skill link 變成文字檔，skill 載不到 | `setup.ps1` 檢查 `core.symlinks` 並提示；不通過時改由 setup 建立 link |
| Windows 沒有 `python3` 指令 | shoal guard 與 python 類 hook 失敗 | 不在本 spec 範圍；Phase 4 記錄實際狀況後另開 |
| normalizer 改錯不該動的字串 | 設定壞掉 | 只動明列欄位；`--fix` 先寫備份；測試涵蓋引號與巢狀情境 |
| `additionalDirectories` 不支援 `~` | 那 4 條無法可攜 | 列為例外；這 4 條只影響該機器能讀的額外目錄，路徑不存在時無害 |

## 待決事項

1. agy 的 `antigravity-cli/settings.json`（29 處）要等確認 agy 是否展開 `~`；
   不展開的話改由 setup 產生。
2. `.claude/settings.local.json` 目前被版控且內含 Mac 路徑，要不要一併移出
   版控；本 spec 預設不動。
3. `node` 只靠 nvm lazy-load 提供、`/bin/sh` 的 hook 找不到（`i-have-adhd`
   plugin 因此失效）已另外處理：`nvm.zsh` 把 nvm default 的 `bin` 放進 PATH。
