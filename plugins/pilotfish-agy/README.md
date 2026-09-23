# pilotfish-agy

Pilotfish orchestration 的 agy（Antigravity CLI）版本。角色契約與流程改寫自
`plugins/pilotfish-grok`，安裝面換成 agy 原生的 custom agent、skill 與 global
rules。設計與實測紀錄見 `docs/specs/pilotfish-agy/SPEC.md`。

## 內容

| 檔案 | 安裝到 | 作用 |
|---|---|---|
| `templates/agents/<role>/agent.md` | `~/.gemini/config/agents/<role>` | 7 個角色：tier 與工具限制 |
| `templates/skills/pilotfish-orchestration/` | `~/.gemini/config/skills/` | 完整流程，需要時才載入 |
| `templates/rules/pilotfish-agy.md` | 併入 `~/.gemini/GEMINI.md` | 常駐短規則：角色名單與硬性 gate |

| Role | Tier | 工具 |
|---|---|---|
| `scout` | flash | 唯讀 |
| `mech-executor` | flash | agy 預設全套 |
| `plan-verifier` | pro | 唯讀 |
| `security-reviewer` | pro | 唯讀 + web |
| `executor` | pro | agy 預設全套 |
| `verifier` | pro | 唯讀 + `run_command` |
| `security-executor` | pro | agy 預設全套 |

## 安裝與驗證

```bash
bash script/common/setup_gemini.sh                     # 安裝
python3 -m unittest discover -s plugins/pilotfish-agy/tests   # 靜態與安裝測試
bash plugins/pilotfish-agy/tests/e2e.sh                # 實際呼叫 agy，會用到 quota
```

## 限制

- agent.md 的 `model` 只接受 tier（`flash` / `pro` / `inherit`）。填具體 model
  ID 會讓 agent 靜默失效，所以 Claude、GPT-OSS 不能當 subagent。
- `verifier` 要跑測試，需要 `run_command`，而 shell 本身可以寫檔；這一點只靠
  prompt 約束，與 Claude 版 pilotfish 相同。
- headless（`agy -p`）下 `run_command` 需要 `antigravity-cli/settings.json` 的
  allow 規則，否則會被自動拒絕；互動模式會照常詢問。
- 主 session 的 model 不強制，用 `/model` 自行選擇。複雜任務建議主 session 用
  Pro，Flash 對 gate 的遵循度較差。
