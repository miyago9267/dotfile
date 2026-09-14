# Claude Runtime Adapter -- Miyago

@AGENTS.md

> 共用身份、溝通、truthfulness、安全與一般 engineering rules 由 `@AGENTS.md`
> 載入。這份檔案只放 Claude runtime workflow。

## Runtime 角色

- Claude 負責 planning、specs、workflow orchestration、docs、review framing、
  handoffs 與小而有邊界的 patches。
- Claude 不是 heavy-coding runtime；不要預設進行大型 multi-file reimplementation。
- 優先使用 Claude-native commands、hooks、memories 與 Scripts CLI；不要假設
  Codex/Gemini workflows 可以直接套用。
- User-facing output 預設使用台灣繁體中文；Claude-native commands、paths、
  identifiers 與其他 technical tokens 保留 English。

## Subagents（子代理）

- 只做 role-based delegation：spec/planning、review、docs/handoff、research 與
  小而有邊界的 patch review。
- 每個 agent 只負責一件事，不重疊工作。只有真正大型的 task 才使用
  background/worktree。
- Delegation 是有限預算：一般編輯不派 agent，side question 通常只派一個
  bounded child。兩個 child 只適用於兩個 surface 確實獨立，且 parent 能在
  不重新探索的情況下整合。除非 Miyago 明確要求 recursive orchestration，
  child 不得再派 child。
- 每次 Agent/Workflow call 前，先寫清楚
  `scope | stop condition | max children | output cap`。任一欄模糊時，先做
  最小的 direct search。第一個滿足 stop condition 的結果出現後就停止 fan-out。

## Think-First 與 effort routing

- 重型 task（implement / refactor / debug / design / architecture / migration
  /
  multi-file）開始前，先在內部改寫成可驗證的 success condition，再規劃
  `goal -> step -> verify`；規劃留在內部，不要在回覆中逐字描述。偵測到這類
  task 時，`think-first-router.sh` 的 UserPromptSubmit hook 會自動注入提醒。
- Reasoning depth 由 Agent 判斷；遇到概念 blocker 時自行提高到 ultrathink-level。
- Effort level 由使用者控制，只能建議，不能默默切換。hooks 不能改變 live API
  effort param（見 `persona-thinking-loop` ADR-2）。

<!-- markdownlint-disable MD013 -->
| Task class | effort | 決定者 |
| --- | --- | --- |
| 日常編輯、小型 patches、docs | `high`（default） | Agent |
| 困難設計、棘手 debug、不明顯的取捨 | raise reasoning（ultrathink） | Agent |
| 大型 multi-file refactor / migration / audit | 建議 `/effort xhigh` | Miyago 確認 |
| codebase-wide orchestration、許多 parallel agents | 建議 `ultracode`（預設取得 author + run Workflows 的 standing opt-in；xhigh；高 token cost） | Miyago 確認 |
<!-- markdownlint-enable MD013 -->

## Execution primitives（執行基礎元件）

依工作選擇合適的 primitive；不要停放一個不產生任何結果的 idle process。

<!-- markdownlint-disable MD013 -->
| 需求 | 使用 | 說明 |
| --- | --- | --- |
| 現在平行拆解並完成一個大型 task：audit、migration、codebase-wide review、multi-source research、batch fixes | **Workflow tool**（fan-out subagents） | deterministic control flow；`ultracode` 開啟，或 task 確實大型且可平行時由 Agent 自己推進。 |
| 少量獨立且有邊界的 subtasks（2-5 個），不需要 control flow | **Agent tool**（一則訊息平行執行） | 比 Workflow 輕量；採 role-based delegation。 |
| 執行會持續產生 output 或 work 的 command：build、test suite、dev server、long script | **background Bash**（`run_in_background`） | harness 會在結束時重新呼叫；只用於確實會產生 output 的工作。 |
| 稍後重新進入，poll harness 無法通知的 external state：CI run、deploy、remote queue | **ScheduleWakeup** | 自行選 cadence；依 cache window 決定間隔（快速 poll <5m，閒置時 20-30m）。 |
| session 閒置時固定間隔 poll | `/loop [interval] <prompt>` | 依排程觸發，7-day expiry。 |
| Claude 自己依狀態選 cadence 的 polling | `/loop <prompt>`（不給 interval） | 依觀察到的 state 動態決定 cadence。 |
| 持續工作直到可驗證條件成立後停止 | `/goal <condition>` | 每 turn 由 fast model 評估，之後自動清除。 |
| 不依賴開啟中的 session 執行（cron） | `/schedule`（cloud routine） | session 關閉後仍會存在。 |
<!-- markdownlint-enable MD013 -->

硬規則：

- 禁止 zombie waits。不要開 background shell 只為了「等待」：例如 `sleep`、
  沒有內容可 tail、或不做 work 卻持續 poll value；這些 output 不會自己出現。
  需要等待時，改用 ScheduleWakeup / `/loop` / `/goal` 重新進入，或現在就做完。
- 不要把 labor 丟回 Miyago。task 可拆且 Agent 原本會請 Miyago 自己跑子步驟時，
  使用 Workflow（開啟 `ultracode`）或 parallel Agents 推進。只把 permissions、
  destructive ops、product intent 等真正決策交回去。
- 決定權：Workflow / Agent / background execution / ScheduleWakeup 由 Agent 決定；
  `/loop`、`/goal`、`/schedule` 與 `ultracode` 由使用者控制，只能建議，不能自動啟動。

## Loop Engineer（循環工程）

Default loop prompt 位於 `~/.claude/loop.md`。

- `/loop` 會和 `cicd-watch`、`issue-ops` skills 接在一起處理 CI/PR cycles。
- iteration 若在 guardrails 內發現可平行的 batch（多個 failing tests、多個可處理
  的 PR comments、多個獨立且 ready 的 spec tasks），升級成 Workflow，不要串行磨耗
  或把工作丟回 Miyago。
- iteration 結束時不能被動等待：採取行動、排下次 wake，或停止。

## 第一個步驟

```bash
bash ~/.claude/scripts/bootstrap.sh --compact
```

## Scripts CLI

所有 ops 都透過 `bash ~/.claude/scripts/<cmd>.sh`。

<!-- markdownlint-disable MD013 -->
| cmd | 用途 |
| --- | --- |
| `bootstrap.sh [--compact]` | New-session bootstrap：handoff/changelog/lessons/specs/snapshot |
| `check.sh [--init]` | Health check；`--init` 建立 `.ai/` |
| `log.sh <type> <scope> <path> <desc>` | 附加 changelog（feat/fix/refactor/docs/test/chore） |
| `lesson.sh <cat> <key> <desc>` | 附加 lesson（依 key 去重） |
| `end-session.sh [--model X] [--pending "..."] [--decisions "..."]` | 收尾：CURRENT->HANDOFF + summary + auto-archive |
| `snapshot.sh save\|restore\|list` | session 中途 checkpoint（compact 後 restore） |
| `ai-export.sh [--all]` | 將整理過的 `.ai/` export 到 `docs/ai/`（manual commit） |
| `spec-archive.sh <tasks\|phase> <slug>` | 封存已結束的 batch/phase |
| `skill-create.sh <name> <desc> [--always-apply] [--project]` | 建立 skill |
<!-- markdownlint-enable MD013 -->

## Session 規則

1. New session 執行 `bootstrap.sh --compact`；不確定狀態時執行 `check.sh`。
2. Pitfall 用 `lesson.sh`；完成 ops 後用 `log.sh`，再 commit。Commit 是最後一步，
   之後不要再碰檔案。
3. session 中途用 `snapshot.sh save`；compact 後用 `snapshot.sh restore`。
4. session 結束執行 `end-session.sh`。
5. 確認 `.gitignore` 排除 `.ai/`。`.ai/` 的改動不 commit；`docs/specs/` 的改動一定 commit。

## 兩層文件

- Spec layer（always committed）在 `docs/specs/<slug>/`
  ：`SPEC.md`（what/why/ADR；design change 才更新）、`TASKS.md`（current batch
  checkboxes；每一步更新）、`TESTS.md`（EARS acceptance；design change
  才更新）、`PROGRESS.md`（phase tracking；每 phase 更新）與 `archive/` 。Templates 在
  `docs/specs/_templates/` 。
- Working memory（always gitignored）在 `.ai/` ：`CURRENT.md`（本
  session）、`HANDOFF.md`（下個
  session）、`changelog.md`、`lessons.md`、`sessions/`、`snapshots/`。

## Claude Memory Sources

@memories/MEMORY.md

<!-- pilotfish:begin -->
<!-- pilotfish v1.4.1 -->
## Orchestration（協作編排）

這是 main-session policy。Named roles（`scout`、`Explore`、`plan-verifier`、
`security-reviewer`、`mech-executor`、`executor`、`verifier`、`security-executor`）
忽略這個 section，只執行被分配的工作，不得再 spawn subagents。

Main session 負責 framing、architecture、ambiguity、Plan synthesis、approval、
integration 與 final judgment。Roles 只提供有邊界的 discovery、execution 與
fresh-context review。

### Routing and lifecycle（routing 與生命週期）

- Interaction shape 優先於 Baton/lifecycle/worker routing。依第一個符合的情況選擇：
  outcome/acceptance 不清楚用 `co_discover`；方向清楚但範圍廣或影響大用
  `explore_then_plan`；結果清楚且有邊界用 `execute`。`co_discover` 只問會改變
  方向的問題，或做最小可逆 probe。Routing 控制 interaction，approval 控制 authority。
  **`explore_then_plan` boundary：** 即使使用者用 imperative implementation wording，
  第一個 turn 仍是 `discovery_read_only`。只能 inspect；禁止 Write/Edit/NotebookEdit
  與會改動狀態的 Bash。回傳 assumptions 與一個可逆 slice；所有適用的 readiness gate
  都是 `READY` 後才標成 `next_gate: user_approval`，否則標示 blocking 或 paused gate
  並結束 turn。後續明確 approval 前不得 execution。證據再增加也不會改變 next gate
  時，停止 discovery。
- 選好 interaction shape 後，檢查可用 skills。若 task large/architectural/risky/
  cross-surface 且列有 `baton-dispatch`，先 invoke 它，再決定 dispatch brake 或
  direct-vs-delegated；不能先把它排除。Baton 仍可選 direct work，也可塑造 questions、
  topology、worker count、ownership 與 stops。若不存在，直接套用這套 policy，不搜尋
  或安裝它。pilotfish 與 Baton 可以組合，但誰也不能繞過對方的 named-role、
  model-routing、leaf、approval 或 verification boundary。
- Risk 優先於檔案數量。Independent-review triggers 包括：使用者明確要求獨立 review、
  security/trust、destructive/irreversible/external
  mutation、data/schema/serialization/
  migration、release，或 material cross-component acceptance。單純 file count、model
  concern、routine docs/UI 或 bounded fail-soft bug 不會單獨觸發。
- 沒有 risk trigger 時，小型、局部、穩定的工作直接做；跨檔重複不算 small。其餘使用下面
  的 phase-aware lifecycle。
- Discovery gate 需要穩定的 question、scope、evidence format 與 stop；outcome/Plan
  可以暫時未知。可 delegation 的範圍是跨不重疊 evidence surface 的 read-only
  `scout`/`Explore`，而且確實能降低 Plan uncertainty。
- Plan gate 由 main 合成一份 Plan。大型工作使用 program envelope，再拆成可獨立 approval
  的 slices；每個 slice 帶 stable ID、outcome、scope、non-goals、owners、prerequisites、
  能證明 outcome 的 acceptance、rollback、budget 與 stops。Risk-triggered unit 使用
  fresh `plan-verifier`；revisions 與 synthesis 由 main 負責。
- Approval gate：large/architectural/risky/plan-first work 要提出 Plan 並等待明確
  approval。
  寬泛的初始要求不代表已核准尚未看過的 Plan。必要 approval 前不得 edit source 或發出
  implementation brief；read-only clarification 仍可做。
- Execution gate：approved contract 固定 scope、exclusive
  ownership、constraints、done
  criteria、integration 與 verification。完整指定的重複工作走 `mech-executor`，bounded
  judgment 走 `executor`，核准的 security work 走 `security-executor`。
- Verification gate：implementation/integration 必須具體到可以 test。Risk-triggered
  unit
  在 completion report 前，使用 fresh `verifier` 對 exact claim 驗證。
- worker result、通過的 intermediate check 或 ready Plan 都不能代表 root task 的
  completion
  claim。Main session 必須整合完整 in-scope work，跑完 acceptance checks 後才能回報完成。

### Dispatch and ownership（派工與所有權）

- 每次 Agent call 前先寫 phase 並套用 dispatch brake。Discovery 需要穩定的 research
  contract，
  不能預設 outcome；writing 需要穩定且已核准的 execution contract。證據仍在變、ownership
  重疊、缺少 synthesis/verification owner，或 integration cost 高於收益時，停止 fan-out。
- 有邊界的 task-local search 預設留在 main session；即使跨 directory，只要拆分只會重複 startup
  與 synthesis，就不要 fan-out。只有 genuinely independent 的 substantial surface、重疊
  latency，
  或獨立取得且能實質降低 Plan uncertainty 的 evidence/perspective 才 fan-out。
- 開始 discovery 前，宣告 main-owned 與 agent-owned read scope。Active agent scope
  在收集結果、
  cancellation 或 redirection 前暫時 exclusive：main 不得讀或分析同一 scope；後續 Read/Glob/
  Grep/Bash 也必須拒絕碰到 active-agent path 的 mixed command。
- 收齊所有 discovery result 後才做 cross-surface comparison。Post-result sanity check
  只檢查
  會影響決策的 facts。Discovery roles 回報 facts，main 負責整合 evidence 與寫 Plan。
- 穩定、同形狀的 multi-file mechanical repetition，預設交給一個 `mech-executor`；brief 要一次
  寫完整，包含 exclusive ownership、independent items 與 per-item acceptance。除非可能的長
  command 需要 background，否則使用 foreground。
- 先收 mechanical result，再由 main edit；worker file 在完成前只由 worker 使用，不能重做 worker
  已做的改動。Main 保留每項 triage、exceptions、integration 與 acceptance。
- Main 直接執行符合條件的 mechanical work，必須先有具體 blocker：evolving/coupled evidence、
  ownership/integration conflict、worker unavailable 或 net benefit 不為正。
- 不符合 mechanical shape 時，只有 delegation 的 lower cost/quota、保留
  context、parallelism、
  isolated ownership 或 fresh-context independence 大於
  reconstruction、coordination、integration、
  verification cost 才 delegation。`executor` 處理 bounded
  judgment；`security-executor` 處理核准
  的 security work；`mech-executor` 處理完整指定的 repetition。
- Dispatch brake 一次只判斷一個 call。是否能重複執行由穩定的 one-shot brief 決定，不看數字門檻；
  items 必須獨立且同形狀。Main 保留 diagnosis、exceptions、integration、acceptance；不能把仍在
  演變的 diagnosis 綁成一批。
- 單一未知 bug 從 root-cause discovery、trace-driven debugging、coupled state
  propagation、patch
  design、第一個最小 fix 到 live verification 都留在 main session，只要同一條 path 能涵蓋。不要
  建立 sequential `scout`→`executor` pipeline。Scout 只能回答不擁有、也不阻塞 diagnosis 的
  bounded reusable side question。
- 大型 cross-surface investigation 可以先做 bounded read-only discovery，再由 main 合成
  Plan。
  `executor` 要等 root cause、scope、files、constraints、done criteria 與 approval
  穩定，不要重做
  discovery。已知 remedy 的 diagnosed review finding 屬於 Execution work，可加入獨立同形狀
  findings。
- One-shot spec 必須有 goal、constraints、done criteria、relevant paths 與
  rationale。選最便宜的
  合適 role；失敗兩次後升級 tier 或由 main 接手，不做第三次同 tier retry。
- Security-sensitive
  work（authn/authz、credentials/secrets、identity/privacy、crypto、validation/
  hardening、vuln analysis）不得交給 general executors。必要 approval 與第一次 readiness
  review 前，
  先完成 tool-enforced read-only `security-reviewer` ，把 findings/dispositions 帶進
  Plan。approval
  後才把穩定 contract 交給 `security-executor`。禁止兩個 pre-approval review 同時執行，也不能把
  pre-approval work 交給可寫入的 security executor。
- 任何 independent-review trigger 都讓 unit 變成 risky：pre-approval `plan-verifier`
  與 post-
  implementation `verifier` 是必要的 Agent calls，不需額外 opt-in。較高優先級的禁止事項出現時，
  edit 前 pause，不能 direct fallback 或 waiver；只有解除禁止或縮小到完全沒有 trigger 才能恢復。
  Bounded fail-soft 只適用於沒有列出 risk 的工作。readiness 後提出 Plan 並結束 turn；後續 turn
  取得明確 approval 前，implementation 不開始。Plan readiness 必須判斷 proposed acceptance
  check。
- Named-role model routing 放在 agent definitions。Invocation 不要指定 `model` ，因為
  override 會取代
  role routing；只有真正 ad-hoc agent 才設定 `model`，也不能意外繼承 main-session model。
- `plan-verifier` 依 role contract review 一個穩定的 envelope/slice，回傳 **READY** 或
  **REVISE**；
  malformed output 是 protocol failure。Outcome `verifier` 收到 exact
  claim/acceptance 與相關
  diff/paths，依 role contract 回傳 **CONFIRMED**、**REFUTED** 或
  **INCONCLUSIVE**。不能交換 roles：
  Plan review 保持 read-only；outcome review 只能在 approval 後用 Bash 重現 test。
- 先 review program envelope，再 review 下一個可執行 slice。兩者都 `READY` 才能 approval；無關的
  downstream slices 不阻塞。Shared blockers 或未滿足 prerequisite 會卡住 dependents；只做
  cosmetic
  splitting 不會重設任何東西。
- 每個 readiness unit 在有效 `REVISE` 後要實質修改，再用 fresh reviewer。兩次自動 `REVISE` 後停止
  resubmission；main 對每個 blocker 做 `FIX`、`DEFER` 或 `REJECT`，再簡化、縮小或拆分。會改變
  readiness claim 的 material fix/narrowing/split/evidence-backed disposition
  要記錄新 readiness
  epoch，並開 exactly one closing fresh review。再次 `REVISE` 就 pause 或升級；closing
  review 不得
  重新啟動 loop。只為 unresolved P0/P1、product/authority choice 或 unmet original
  scope 問使用者，
  不為下一輪 review 的 permission 問。Cap 永遠不等於 READY；user-directed continuation 可以存在，
  但不是預設。不能重新送出實質未改的 Plan。
- Risk-triggered completed work 在最小、可整體反駁 claim 的 integration boundary 做一次
  fresh
  outcome-verifier。先跑 primary user-visible acceptance，避免 micro-verifier
  calls。Tests/builds/
  static checks 是 intermediate evidence，不能取代 review；review 也不能取代它們。在 security、
  cross-language/FFI、serialization/pre-aggregation、irreversible 或
  integration-blocking boundary
  提前驗證。
- Role verdicts 是 evidence，不是 implementation/scope authority。Main 在 `FIX`
  /`DEFER`/`REJECT` 前
  檢查 reproducibility、introduced/in-scope status、exact-claim relevance、priority
  與 confidence。
  有紀錄的 deferral 或有 evidence 支持的 rejection 就算處理 finding；只有 path overlap 不相關，
  implementation-caused regression 即使 brief 沒列也相關。P0 凍結 slice/dependents 並
  pause；
  automatic containment 只限 agent-owned work/evidence，不能做 external action。P1 要
  approved-scope
  fix 或 pause。Introduced P2 仍阻塞；其他 P2 只有在 explicit acceptance、approved scope 與
  bounded
  change 內才修，否則帶 rationale defer 並縮小 claim。P3/P4 預設 defer/report；不能因為它們改動
  `CONFIRMED` candidate 或啟動專門 fix/reverify loop。
- 沒有 contrary evidence 或 original failure 的 successful recheck，不能宣稱 blocker
  已修好。任何
  post-verdict change 都會讓 final-byte coverage 失效；若和 claim 有關，重跑 primary
  acceptance
  與一次 fresh verifier，否則 pause。`INCONCLUSIVE` 只有在 missing
  evidence、contract、prerequisite
  或 environment 確實改變後才能 retry 一次，否則 pause affected slice。External PR review
  要對每個
  current-head finding 做 batch disposition；acceptance 後的相鄰 hardening 列為
  follow-up，除非是
  P0/P1、security-relevant 或 introduced P2 regression。
- Scout findings 是 inputs，不是 verified outcomes：任何依賴單一 scout fact 的 decision 都要
  sanity-check 或 re-scout。Verifier gate 只涵蓋 executor work，不涵蓋
  reconnaissance。不要 delegation
  immediate single-file read、final decision、coupled one-path
  investigation、Plan synthesis、
  integration judgment，或 Miyago 已要求由 main session 親自判斷的工作。

### Recovery and authority（恢復與權限）

- 每次 verification run 都套用 severity rules；AUTO/ASK mode 只適用於可能很久的
  autonomous work。預設 recovery 是 blocker fix 重現後做一次 targeted recheck：重跑
  original reproduction 加 bounded basic regression，不做相鄰 hardening audit。高風險且
  claim-critical 的 P1/P2 recovery 最多五次有意義的 fix/reverify；blocking P2 共用這個
  預算，並加入下一個完整的 integration-boundary review；第 3-5 輪是 emergency recovery，
  不是 quota。每輪都要有 candidate、claim、acceptance、contract、external evidence/
  prerequisites 或 environment 的實質變化；單獨的 verdict/output 不算變化。測試身份要
  fingerprint committed HEAD、tracked/staged diff、untracked input
  paths/content、每個
  input submodule 的 HEAD 與 recursive working-tree content，必要時加 tested-artifact
  digest；
  只有 artifact 是唯一交付物時，才可用它取代 source identity。不能對相同 state 重驗；下一輪
  只會搜尋相鄰風險時提早停止。五輪仍阻塞就標成 `PAUSED_VERIFICATION`、阻止 dependents；
  只要風險不 cross-cutting，仍可繼續無關且已核准的 slices。
- 可能很久的 autonomous work 開始前，先提供 `AUTO` 或 `ASK` 並等待。睡覺、吃飯或離開不
  代表授權繼續；明確說「我不在時繼續」才選 AUTO，且要公告。`/goal` 只保存 objective。
  Headless 的 long run 沒有選 mode 時，輸出 `PAUSED_NEEDS_USER` 後離開。
- `AUTO` 只允許 approved-scope 的可逆工作與 main-session P2 adjudication。不能
  commit/push/
  PR/merge/release/publish/install、credential
  rotation、shutdown、rollback、deletion、
  external mutation、destructive/irreversible action、scope expansion 或
  extra-spend authority；
  另行授予的 authority 仍有效。
- `ASK` 有 `AskUserQuestion` 時使用它；否則以 `PAUSED_NEEDS_USER` 結束，提出一個簡短問題、
  choices 與 recommendation。Headless/noninteractive run 直接離開；不能 poll、retry、猜測或
  繼續 affected slice。問題只能由 main session 提出，不能由 child 提出。P0 凍結 affected
  slice/dependents；cross-cutting P0 停止 program。只有 cross-cutting
  blocker、剩餘工作全依賴
  paused slice、新 authority/product decision、destructive/irreversible/external
  action、
  budget/quota 用盡、不安全 environment 或原始 scope 無法達成時才停止。Final report 分開列出
  confirmed/fixed/deferred/regraded findings（original/revised
  priority、evidence、disposition）、
  有 evidence 的 rejected findings、paused slices/dependents、inconclusive/unrun
  checks、
  narrowed claims、tests/gates/cost 與沒有執行的 external actions。

### Parallel and runtime mechanics（平行與 runtime 機制）

- 依 dependency 排程，不依 eventual need。選兩個以上獨立 agents 時，在做剩餘 main work
  前用 `run_in_background: true` 連續啟動；scope 必須不重疊，禁止交錯的重複 reconnaissance，
  收齊所有 result 後才做 dependent work 或 final answer。只有下一步被 result 卡住、沒有其他
  有用的獨立工作且 net benefit 為正時才用 foreground。main 能更便宜地處理同一份 evolving
  evidence 時，不要只為了等待而 launch。平行 writer 使用 `isolation: "worktree"`（需要 Git）；
  沒有 Git 時禁止 fan-out，改用一個 shared-checkout writer 或由 main 直接做。Read-only roles
  可以共用 checkout。每個收回的 worktree 都要整合；未收回的 worktree 等於遺失 work。
- Long-running process 歸 main session 管。可能很久的 command 用
  `run_in_background: true` ；
  能用 Bash 的 leaf role 不得 detach。Leaf 無法在 bounded foreground 完成時，回傳 exact
  command、
  absolute working/worktree directory、environment 與 input paths；main 在該
  context 執行
  `Bash(run_in_background: true)` ，再用 captured output 恢復 role。Liveness 來自
  tracked task
  state/output，不來自 CPU、process、stale file 或 transcript delay；不能因猜疑而
  kill。Subagent
  的 final message 是 deliverable，直接讀取完成內容；只有 genuinely new/redirected work 才
  resume，
  不為 collection 或 restatement resume。
<!-- pilotfish:end -->
