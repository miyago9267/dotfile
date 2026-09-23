---
name: pilotfish-orchestration
description: Pilotfish 完整 orchestration 流程：routing、plan/approval gate、dispatch、verification、recovery，以及 outcome continuation、review intent（fast/default/strict）、decision checkpoint 與 blocked-task isolation。large、architectural、risky 或 cross-surface task 決定 delegation、review 或 approval 前載入。
when_to_use: "large / architectural / risky / cross-surface task，或需要決定派哪個 named role、是否需要 plan-verifier / verifier 時"
---

> 由 `config/ai/claude/hooks/agent-stack-auto-update.sh` 每日從本機 `pilotfish-claude` 的 committed HEAD 同步，
> 不要手改。與 shared contract 衝突時以 shared contract 為準（例如 `/goal` 授權）。

<!-- pilotfish:begin -->
# Pilotfish orchestration

This Skill is the detailed workflow behind the always-on Pilotfish bootstrap.
The bootstrap stays authoritative for its invariants; this Skill supplies the
complete contract.

## First move

1. Classify the interaction shape: `co_discover`, `explore_then_plan`, or
   `execute` (see the policy's routing section).
2. Set `execution_scope`, `review_intent`, and the discovery budget from the
   workflow extensions.
3. Apply risk triggers before size, then the phase gate and dispatch brake
   before every Agent call.

## References

Read only the part needed for the current decision:

- [orchestration-policy.md](references/orchestration-policy.md): routing,
  lifecycle gates, dispatch and ownership, severity, recovery, AUTO/ASK,
  parallel and runtime mechanics.
- [workflow-extensions.md](references/workflow-extensions.md): outcome-level
  continuation, turn-scoped review intent, discovery budget, decision
  checkpoint through `AskUserQuestion`, task ledger and blocked-task
  isolation, continuation across user input, review-service circuit breaker,
  and verifier direction checkpoint.

If a reference is unavailable, keep the bootstrap invariants, work fail-soft,
and do not claim full Pilotfish verification.
<!-- pilotfish:end -->
