---
title: ITRD CI And Deployment Checks
description: You continued checking ITRD GitLab CI state across `pms-frontend`, `api-doc`, and `neppan-to-master`. You also used Orca to coordinate agents around deployment issues, while briefly switching through Discord, LINE, and Spotify.
applications: [company.thebrowser.dia, com.stablyai.orca, com.hnc.Discord, jp.naver.line.mac, com.spotify.client]
---

## Memory summary

The user spent this window mainly in Dia and Orca, continuing ITRD CI/deployment recovery and verification. Dia showed GitLab job and pipeline pages for `pms-frontend`, `api-doc`, and `neppan-to-master`; the most important observed failures were `pms-frontend` build job `#675150` still failing on the legacy registry HTTP/HTTPS mismatch, and `neppan-to-master` `Deploy Schedulers` job `#674979` failing because `jq` was missing in the CI image. The user also checked that `neppan-to-master` `Deploy Workflows` job `#674978` passed, and used Orca to keep ITRD and Pilotfish-related agent work moving.

### Relevant prior context

The immediately preceding summaries established that the user was already coordinating ITRD CI recovery. `pms-frontend` MR `!45`, `flutter_housekeeping` MR `!258`, and `flutter_pms_web_plugin` MR `!28` had reached review/merge-ready states, while the remaining `pms-frontend` build issue was tied to the old internal registry image `docker:dunqian-nginx-bun` being fetched with the wrong HTTP/HTTPS behavior. A prior Skysight summary already suggested a reusable GitLab CI triage workflow, so no overlapping suggestion is added here.

### Important non-obvious context about the user

- `/Users/miyago/Project/Active/ITRD`: active Orca workspace for the ITRD deployment/CI work.
- `檢查三項 GitLab 部署問題`: visible Orca tab/work thread for checking multiple GitLab deployment issues.
- `pms-frontend` job `#675150`: current retried build job still failing on the legacy registry HTTP/HTTPS mismatch.
- `api-doc` MR `!820`: merged MR titled `RMS 官網調整比例與金額設定`, branch `official-tune-price-setting`, with pipeline `#74853` passed.
- `api-doc` pipeline `#74924`: user revisited the pipeline and jobs while checking whether the public API docs updated.
- `api-doc` job `#674679`: `build_web_image` job tab was open at the end of the window.
- `neppan-to-master` job `#674978`: `Deploy Workflows` passed.
- `neppan-to-master` job `#674979`: `Deploy Schedulers` failed because `batch-yaml/scheduler/deploy_job.sh` could not find `jq`.
- `pilotfish-codex`: Orca workspace remained visible with ongoing/finished work around Astra planning and install/benchmark checks.
- `winton-clock-in`: visible Orca tab, but no actionable task details were captured in this window.

## Recording summary

### GitLab CI Checks In Dia

- At the start, Dia was on `itrd/new-pms/frontend/pms-frontend` build job `#675150`. The job log showed the build had migrated legacy base images into Artifact Registry paths, then failed while resolving the old `docker:dunqian-nginx-bun` base image because the server returned an HTTP response to an HTTPS client. The job ended with exit code 1.
- The user navigated from the `itrd` GitLab group to `api-doc`, opened its merged merge requests, and inspected MR `!820` titled `RMS 官網調整比例與金額設定`.
- MR `!820` was shown as merged from `official-tune-price-setting` into `master`; its related pipeline `#74853` was shown as passed.
- The user opened `api-doc` pipeline `#74924`, created or used a tab for the public API docs, and checked the RMS API YAML page. The public docs initially showed a browser error page, then loaded.
- The user moved between the public API docs YAML page, the `api-doc` pipeline list, the `api-doc` project page, the merge commit for `official-tune-price-setting`, and the `api-doc` commits view, apparently verifying whether the merged RMS change had reached the deployed docs.
- Later, the user revisited `api-doc` pipeline `#74924`, opened deploy/build job tabs including `deploy_job` `#674965`, and ended with `build_web_image` job `#674679` open.
- Near the end, the user compared several job tabs: `pms-frontend` build `#675150`, `neppan-to-master` `Deploy Schedulers` `#674979`, `neppan-to-master` `Deploy Workflows` `#674978`, and `api-doc` `build_web_image` `#674679`.

### Neppan Deployment Jobs

- `neppan-to-master` `Deploy Schedulers` job `#674979` was shown as failed. The visible log used a `google/cloud-sdk:slim` image, authenticated to GCP, configured `asia-east1`, then failed at `batch-yaml/scheduler/deploy_job.sh: line 27: jq: command not found`.
- `neppan-to-master` `Deploy Workflows` job `#674978` was shown as passed. The visible log showed it deploying the `neppan-to-master-workflow` workflow using an Artifact Registry image tag tied to pipeline `74935`.

### Orca Agent Coordination

- Orca was active several times. It showed the `pilotfish-codex` workspace and agent rows, including a completed Astra analysis artifact under `docs/plans/astra-plan-v2.md` and ongoing commands inspecting `install/install.sh`, `install/install.py`, and benchmark-related docs.
- The user typed short Chinese input fragments into Orca around whether changes had not been updated online, then later selected the ITRD workspace.
- In the ITRD Orca workspace, a visible agent was checking the API docs deployment state with HEAD requests against the API docs host and searching repository files for `rms-api`, `rms-server`, `tune-price-setting`, and `api-doc`.
- Another visible ITRD command inspected `readme.md` and searched for Docker, YAML, GitLab, runtime, and Argo CD-related files.
- Orca showed active tabs including `檢查三項 GitLab 部署問題` and `修正通報機器人同步與送出按鈕`.

### Incidental Apps

- Discord was foregrounded briefly and the user switched across several servers/channels, including an announcements channel. Message contents are not retained.
- LINE briefly became foreground but no useful conversation content was captured.
- Spotify was used briefly for playback or window interaction and appears incidental.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-09T03-20-00Z/events.jsonl
- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-09T03-20-00Z/metadata.json
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T03-10-00-jLKd-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T03-00-00-PmiR-10min-memory-summary.md