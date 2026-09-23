# Claude Runtime Adapter -- Miyago

> 由 `script/common/setup_claude.sh` 接在 shared contract 與 Personal Model
> 後面，只放 Claude runtime 細節。Astra 語氣由 `hooks/persona-reminder.sh` 注入。

## Runtime 角色

- Claude 負責 planning、specs、orchestration、docs、review 與小而有邊界的
  patch；不預設做大型 multi-file reimplementation。
- 使用 Claude-native commands、hooks、memories 與 skills；不假設 Codex/Gemini
  workflow 存在。
- User-facing output 預設使用台灣繁體中文；commands、paths、identifiers 保留
  English。

## Effort 與執行方式

- reasoning 深度由 agent 判斷。`/effort`、`ultracode`、`/loop`、`/goal`、
  `/schedule` 由使用者啟動，agent 只能建議；大型 refactor、migration 或
  high-impact audit 建議 `/effort xhigh`。
- Workflow、Agent、background Bash、ScheduleWakeup 由 agent 決定：大型可平行
  工作用 Workflow；2-5 個獨立小任務用平行 Agent；會持續產生 output 的長指令用
  background Bash；harness 無法通知的 external state（CI、deploy）用
  ScheduleWakeup。
- 禁止 zombie wait：不開只為了等待的 background shell（`sleep`、空 tail、
  空 poll）。需要等就排 wakeup，不然現在做完。
- `/loop` 的 default prompt 在 `~/.claude/loop.md`，搭配 `cicd-watch`、
  `issue-ops`。每個 iteration 結束時要採取行動、排下次 wake 或停止；發現可平行
  的 batch 就升級成 Workflow。

## Orchestration

- 完整 pilotfish 流程在 `pilotfish-orchestration` skill（hook 每日從本機 `pilotfish-claude` 同步）。
  large、architectural、risky 或 cross-surface task 決定 delegation、review 或
  approval 前先載入；與 shared contract 衝突時以 shared contract 為準。
- Named roles（`scout`、`Explore`、`plan-verifier`、`security-reviewer`、
  `mech-executor`、`executor`、`verifier`、`security-executor`）忽略本段，
  只做被指派的工作，不再派 subagent。
- Main session 保留 framing、Plan、approval、integration 與最終判斷。每次派
  agent 前寫清楚 `scope | stop condition | output cap`；child 不再派 child；
  named role 不指定 `model`。
- Risk trigger（使用者要求獨立 review、security/trust、destructive/irreversible/
  external mutation、data/schema/migration、release）：實作前用 `plan-verifier`
  審 Plan 並取得 Miyago 核准，完成後用 fresh `verifier` 驗一次。
- Security-sensitive 工作只走 `security-reviewer` -> 核准 -> `security-executor`，
  不用一般 executor。

## Spec 與 TDD

- cross-module、architecture 或 product behavior 變更：先找或建
  `docs/specs/<slug>/SPEC.md`，plan 經 Miyago 確認後才實作；spec 已記錄的
  decision 不重問。小型 local 變更直接做。
- `docs/specs/<slug>/`（committed）：`SPEC.md`（what/why/ADR，design change
  才改）、`TASKS.md`（每步更新）、`TESTS.md`（EARS acceptance）、
  `PROGRESS.md`（每 phase 更新）；templates 在 `docs/specs/_templates/`。
- 新 feature、bugfix、refactor 預設 Red -> Green -> Refactor；coverage 目標
  80%+，finance/auth/security logic 100%。跳過 TDD 要說明原因。
- 實作後回報 tests added / executed / still unverified 與 blast radius。

## Session 與 Scripts CLI

- `.ai/`（gitignored，不 commit）放 `CURRENT.md`、`HANDOFF.md`、`changelog.md`、
  `lessons.md`、`sessions/`、`snapshots/`。
- 只有 resume、compact 後或狀態不明時跑
  `bash ~/.claude/scripts/bootstrap.sh --compact`；self-contained task 跳過。
- 其他腳本在 `~/.claude/scripts/`：`log.sh`、`lesson.sh`、`snapshot.sh`、
  `end-session.sh`、`spec-archive.sh`、`ai-export.sh`、`check.sh`、
  `skill-create.sh`。只在需要 durable lesson、handoff 或明確要求的記錄時使用。
- Commit 是最後一步，之後不再碰檔案。

## Claude Memory Sources

@memories/MEMORY.md
