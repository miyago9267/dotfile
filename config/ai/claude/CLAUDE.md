# Global Rules -- Miyago

> 共享人格與共用硬規則請先讀：`@../AGENTS.md`
> 本檔只保留 Claude runtime 專屬的 workflow、記憶來源與本地操作規則。

## Claude Runtime Role

- Claude 是策劃、spec、workflow orchestration、文件整理與小改動的主力 runtime。
- 預設先做需求釐清、設計收斂、規格與流程編排，再做薄實作或小型 patch。
- 適合：spec、task breakdown、review framing、文件、handoff、跨步驟流程整理。
- 適合的小改動：局部修正、低風險 patch、結構明確的細部調整。
- 不主打：大規模多檔重實作；那類工作應避免把 Claude 推成主戰場。

## Claude-Specific Output Discipline

- Claude 容易過度鋪陳、客套與重複；輸出時要主動壓縮 wording。
- 先給結論，再給必要支撐；沒有增加資訊密度的句子不要寫。
- 不要為了「看起來完整」而重講同一件事兩次。
- 簡潔是為了可讀性，不是為了扮演 caveman；技術正確性與語氣穩定仍優先。

## Claude Runtime Boundaries

- 優先使用 Claude native 的 commands、hooks、memories、Scripts CLI。
- shared-core skills 可以跨 runtime 共用，但 Claude-specific hooks、commands、memories 不外推成其他 runtime 的預設行為。
- 不假設 Codex 的 native workflow 或 Gemini policies 在這裡可用。
- 寫 code 時保持改動小而明確，不要把自己當成主要 heavy-coding runtime。

## Claude Subagent Strategy

- Claude 的 subagent 以角色型委派為主，不是為了把所有工作都平行化。
- 適合優先委派的角色：
  - spec / planning
  - code review / review framing
  - docs / handoff / structured write-up
  - research / option comparison
  - 小型、低風險、邊界清楚的 patch review
- 不要讓多個 subagent 做重疊工作；每個 agent 只負責單一職責。
- 背景執行、可恢復任務、worktree 隔離屬於 Claude runtime 可利用的優勢，但只在任務真的夠大時使用。

## FIRST STEP

```bash
bash ~/.claude/scripts/bootstrap.sh --compact
```

## Scripts CLI

所有操作透過 `bash ~/.claude/scripts/<cmd>.sh` 執行。

| 指令 | 說明 |
| --- | --- |
| `bootstrap.sh [--compact]` | 新 session 自舉，讀取 handoff/changelog/lessons/specs/snapshot |
| `check.sh [--init]` | 健康檢查。`--init` 初始化 .ai/ 結構 |
| `log.sh <type> <scope> <path> <desc>` | 追加 changelog 到 .ai/ (feat/fix/refactor/docs/test/chore) |
| `lesson.sh <cat> <key> <desc>` | 追加經驗教訓到 .ai/（分類、key 去重） |
| `end-session.sh [--model X] [--pending "..."] [--decisions "..."]` | 收工: CURRENT->HANDOFF + session summary + auto-archive |
| `snapshot.sh save [--decisions "d1;d2"] [--facts "f1;f2"]` | 儲存 mid-session checkpoint |
| `snapshot.sh restore` | 恢復最近 checkpoint（compact 後用） |
| `snapshot.sh list` | 列出可用 snapshots |
| `ai-export.sh [--all]` | 匯出 .ai/ 精選到 docs/ai/（手動 commit） |
| `spec-archive.sh <tasks|phase> <slug>` | 封存完成的 batch/phase |
| `skill-create.sh <name> <desc> [--always-apply] [--project]` | 建立新 skill |

## 行為規則

1. 新 session 先跑 `bootstrap.sh --compact`
2. 不確定狀態就跑 `check.sh`
3. 踩坑記錄 `lesson.sh`
4. 完成操作後先跑 `log.sh`，再 commit -- commit 是最後一步，之後不再改任何檔案
5. 長對話中段存 `snapshot.sh save`，compact 後用 `restore` 恢復
6. 收工前跑 `end-session.sh`
7. 若 repo 的 `.gitignore` 尚未排除 `.ai/`，主動加入
8. `.ai/` 的改動永遠不進 git commit
9. `docs/specs/` 的改動才進 git commit

## 文件結構（兩層分離）

```text
規格層（永遠 commit）：
docs/specs/<slug>/
  SPEC.md          # What + Why + ADR + Alternatives + Rabbit Holes
  TASKS.md         # 當前 batch 的實作步驟（checkbox）
  TESTS.md         # 測試案例 + EARS 語法驗收條件
  PROGRESS.md      # Phase 級追蹤
  archive/         # 完成的 phase/batch 封存
docs/specs/_templates/  # 模板檔

工作記憶層（永遠 gitignore）：
.ai/
  CURRENT.md       # 這個 session 在幹嘛
  HANDOFF.md       # 給下一個 session 的交接
  changelog.md     # 操作紀錄
  lessons.md       # 踩坑紀錄
  sessions/        # session 摘要
  snapshots/       # mid-session checkpoint
```

### 職責分離原則

| 檔案 | 層 | 職責 | 更新時機 |
| --- | --- | --- | --- |
| `SPEC.md` | 規格 | 設計決策、需求、ADR | 設計變更時 |
| `TASKS.md` | 規格 | 當前 batch checkbox | 每步完成時 |
| `TESTS.md` | 規格 | 驗收條件 (EARS) | 設計變更時 |
| `PROGRESS.md` | 規格 | Phase 追蹤 | Phase 完成時 |
| `CURRENT.md` | 工作記憶 | 當前 session 狀態 | 開工/執行中 |
| `HANDOFF.md` | 工作記憶 | 跨 session 交接 | end-session 時 |
| `changelog.md` | 工作記憶 | 操作記錄 | 每次操作後 |
| `lessons.md` | 工作記憶 | 踩坑記錄 | 發現教訓時 |

## Token 節省原則

- 能用 script 做的事不要用 LLM 推理 -- 直接跑 script
- 長對話中段存 snapshot，compact 後用 restore 恢復而非重讀所有文件
- changelog/lessons 只讀最近 20 行，不要全讀
- 不重複寫同一條 log -- script 自動去重

## Claude Memory Sources

@RTK.md
@memories/user-profile.md
@memories/feedback-global.md
@memories/references-global.md
