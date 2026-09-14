---
title: GCP Cost And GitLab CI Checks
description: You continued tracing a recent GCP billing/resource spike, moving from Cloud Scheduler and Batch into GitLab CI/MR state for review-crawler. You also used Orca to check active worktrees and send brief follow-up prompts about the cost spike and remote update/docs work.
applications: [company.thebrowser.dia, com.stablyai.orca, com.apple.TextInputSwitcher]
suggestion:
  type: skill
  name: GCP cost investigation
  description: Investigate my recent GCP bill spike by correlating billing reports, projects, Compute Engine, Batch, Scheduler, and CI deployment activity.
---

## Memory summary

The user continued an infrastructure and CI investigation centered on GCP project costs/resources and internal GitLab pipeline state. They started on Google Cloud Scheduler for `develop-1386`, checked scheduled workflow jobs and Batch jobs, briefly switched project context into `production-1386`, then used Orca to ask an agent about the rapidly rising bill over the last two or three months, with Compute Engine appearing as the suspected source. The latter half focused on GitLab `itrd / 資料組 / review-crawler`, where the user checked Agoda review-related merge requests, compared `.gitlab-ci.yml` between `fix/agoda-reviews` and `master`, verified passed pipelines/jobs, and reviewed the already-merged scheduler `jq` fix.

### Relevant prior context

The 08:20 summary showed the user inspecting Google AI Studio spend/billing and GCP resources across `production-1386` and `develop-1386`, ending on Cloud Scheduler for `develop-1386`. The 08:00 summary showed an earlier `itrd / 資料組 / modeling` deploy failure involving a `workflows.workflows.get` permission denial for workflow `model-training` in `develop-1386`, authenticated with a service account from `production-1386`; that explains the surrounding GCP/GitLab troubleshooting context.

### Important non-obvious context about the user

- `develop-1386`: GCP project used for Cloud Scheduler and Batch inspection in this window.
- `production-1386`: GCP project briefly selected while moving through Batch, Cloud SQL, and GKE pages; also appeared in an Orca-visible artifact registry image push.
- `Cloud Scheduler`: user inspected job rows including `check-jobs`, `room-sync-etl`, `price-gap-sync`, multiple `generic-price` jobs, and paused `auto-booking-a1-*` jobs.
- `Batch jobs`: user inspected `develop-1386` Batch rows where several `mastripms-*` and `wise-*` jobs used `e2-standard-2`, `5.86 GB`, and `2 vCPU`; some `mastripms-north-google-price-a2-d30-group*` rows showed failed status.
- `review-crawler`: internal GitLab project under active MR/pipeline checking.
- `MR !30`: `修正 Agoda 評論評分解析`, pipeline `75078`, commit `2eb4212a86cc72e06f0142612b86b6d6953bf883`, and build job `#675598` were visible as passed.
- `MR !29`: `fix: 補齊 scheduler runtime 的 jq`, branch `fix/scheduler-jq-runtime` into `master`, was visible as merged and passed; its visible description said it installed `jq` before scheduler deploy and verified `jq --version`.
- `MR !31`: `Draft: Fix/agoda reviews` was opened, with the user navigating to its diffs and pipeline `75084`, which was visible as passed.
- `Orca ITRD workspace`: visible agent work included building and later pushing a runner image tagged `itrd/testing-runner:17.6.0-toolchain-20260909` / `asia-east1-docker.pkg.dev/production-1386/base/gitlab-runner-testing:17.6.0-toolchain-20260909`.

## Recording summary

### GCP Resource And Cost Investigation

- At 08:30, Dia was on Google Cloud Scheduler for `develop-1386`. The visible list included enabled jobs such as `check-jobs`, `room-sync-etl`, `price-gap-sync`, and several Google price jobs, alongside multiple paused `auto-booking-a1-*` jobs scheduled at different hours.
- The user moved from Cloud Scheduler to Batch jobs for `develop-1386`. The Batch list showed many generated job rows, including `mastripms-*`, `wise-*`, `agoda-reviews-*`, `google-reviews-*`, `check-jobs-*`, and `batch-clean-job-*`.
- Several Batch rows were visible with successful status, but at least some `mastripms-north-google-price-a2-d30-group*` rows showed failure. Many visible price/calendar job rows used `e2-standard-2`, `5.86 GB`, and `2 vCPU`, which may have been relevant to the cost investigation.
- The user switched from `develop-1386` to `production-1386`, briefly opened Batch, Cloud SQL, and GKE pages, then returned to Orca.
- In Orca, the user opened/selected an ITRD-related workspace and launched or interacted with a Grok tab. The typed prompt fragments resolved into a request to investigate a bill that had risen sharply over the past two or three months; a later prompt fragment indicated the suspected source was Compute Engine.
- No direct GCP setting change, deployment, deletion, or export was visible in the GCP console during this window.

### GitLab review-crawler CI/MR Checks

- Around 08:34, the user returned to Dia on the internal GitLab `itrd / 資料組 / modeling` project page, which still showed the broader data-science GitLab context.
- They navigated up to the `資料組` group, opened `review-crawler`, then opened its merge requests.
- The user inspected `MR !30` titled `修正 Agoda 評論評分解析`, including commits and pipelines. Pipeline `75078` was visible as passed, and build job `#675598` was also visible as passed.
- The user opened `.gitlab-ci.yml` on branch `fix/agoda-reviews`, then opened `.gitlab-ci.yml` on `master` and used blame. The visible file sizes differed slightly: branch file about `3.40 KiB`, master file about `3.51 KiB`.
- They opened merged `MR !29` titled `fix: 補齊 scheduler runtime 的 jq`. It was visible as merged, with branch `fix/scheduler-jq-runtime` merged into `master`, and status passed. The visible MR description tied the change to installing `jq` before the scheduler deploy job and checking `jq --version`.
- The user opened draft `MR !31` titled `Draft: Fix/agoda reviews`, navigated toward its diffs, and opened pipeline `75084`, which was visible as passed.
- The GitLab work ended with the user switching back to Orca rather than making a visible edit or merge action.

### Orca Workspace State

- Orca showed several worktrees/projects including `dotfile`, `pilotfish-codex`, `new-pms`, and an ITRD workspace.
- The user clicked through the ITRD and VM migration tabs, then later selected `pilotfish-codex` and `dotfile`.
- Visible agent rows included a completed `pilotfish-codex` task around version `1.8.0-rc.1`, completed dotfile/Neovim-related tasks, and an active ITRD terminal row.
- The ITRD terminal row showed an agent building a Docker-based GitLab runner/testing image earlier, and later pushing a production artifact registry image with tag `17.6.0-toolchain-20260909`.
- Near the end, the user typed in Orca that docs could be updated first and then pushed to remote, but no completed remote push result for that instruction was visible inside this 10-minute window.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-09T08-30-00Z/events.jsonl
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T08-20-00-bnLw-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T08-00-00-gXXv-10min-memory-summary.md