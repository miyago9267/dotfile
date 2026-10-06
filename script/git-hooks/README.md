# git-hooks

`core.hooksPath` 指向本目錄（`script/common/setup_dotfiles.sh` 會設定，也可手動
`git config core.hooksPath "$PWD/script/git-hooks"`）。

`pre-commit`：staged 檔案碰到下列路徑時，commit 前先跑對應測試；失敗會擋下並印出重跑指令。

| staged 路徑 | 執行 |
| --- | --- |
| `config/ai/claude/hooks/**`、`config/ai/shared/jev/**` | `bash config/ai/claude/hooks/tests/run-all.sh`（約 2 分鐘） |
| `script/utils/agent-secret*`、`script/utils/tests/**` | `bash script/utils/tests/test_agent_secret.sh`（約 30 秒） |
| `config/ai/claude/settings.json` | `jq -e .`（讀 index 內容） |

- 逃生門：`DOTFILE_SKIP_TESTS=1 git commit ...`（會印提醒；不要用 `--no-verify`）。
- 測試跑的是工作區內容，不是 staged 內容；部分 stage 時會印警告。
- 缺 `jq` 或 `python3` 時印提示並略過，不擋 commit。
- hook 自身的測試：`bash script/git-hooks/tests/test_pre_commit.sh`。
