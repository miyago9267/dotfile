---
title: GitLab Deploy Failure And Connectivity Checks
description: "You checked an internal GitLab deploy workflow failure, then adjusted VPN/Wi-Fi connectivity and returned to the modeling project page. You also briefly switched through Orca, Discord, Steam/media browsing, LINE, Finder, Spotify, Parsec, and Raycast without a completed durable action outside the GitLab/connectivity thread."
applications: [com.apple.controlcenter, com.apple.dock, com.apple.dock.helper, com.apple.finder, com.hnc.Discord, com.raycast.macos, com.spotify.client, com.stablyai.orca, company.thebrowser.dia, jp.naver.line.mac, org.openvpn.client.app, tv.parsec.www]
---

## Memory summary

The user began this window on an internal GitLab job for `itrd / 資料組 / modeling`, where deploy workflow job `#675612` had failed during `gcloud.workflows.deploy`. The visible failure was a GCP IAM permission error for `workflows.workflows.get` on the `model-training` workflow in `develop-1386`, while the job was authenticated as the artifact-registry service account from `production-1386`. The user then worked on local connectivity by toggling Wi-Fi and repeatedly disconnecting/reconnecting OpenVPN before returning to GitLab, where the `modeling` project page still showed the master pipeline failed for commit `e407335b`.

### Relevant prior context

The immediately preceding 07:50 summary already showed the same internal GitLab `modeling` deploy workflow job with a permission-related deployment failure, but no remediation had been completed. The prior 07:40 and 07:50 summaries also showed an ongoing Discord support-coordination thread around a sensitive wellbeing concern; that context explains later brief Discord switching, but no safe durable message content was established in this window.

### Important non-obvious context about the user

- `itrd / 資料組 / modeling`: internal GitLab project under active deploy troubleshooting.
- `job #675612`: failed deploy workflow job the user inspected at the start of the window.
- `pipeline 75080`: failed pipeline link visible after returning to GitLab.
- `Project ID: 389`: visible GitLab project identifier for `modeling`.
- `commit e407335b`: master commit shown as failed; commit title was `Merge branch 'develop' into 'master'`.
- `model-training`: workflow being deployed when the job failed.
- `develop-1386` and `production-1386`: GCP project names involved in the IAM mismatch or cross-project deploy context.
- `artifact-registry-user@production-1386.iam.gserviceaccount.com`: service account shown as the active deploy identity in the failed job.
- `batch-yaml/workflow/deploy.sh`: script invoked by the job before the permission failure.
- `OpenVPN Connect`: the user attempted to restore or reset VPN connectivity during the GitLab troubleshooting flow.
- `com.stablyai.orca`: Orca workspace was opened briefly; visible state included active ITRD/default workspaces and agent activity, but no completed Orca action in this window.

## Recording summary

### GitLab Deploy Failure

- At 08:02, Dia showed the GitLab job page `Deploy Workflows (#675612) · Jobs · itrd / 資料組 / modeling`.
- The GitLab page itself warned that an error occurred while fetching the job and the displayed log might not be accurate.
- The visible log showed GitLab Runner `17.6.0` using a `docker-autoscaler` executor and `google/cloud-sdk:slim`.
- The job checked out `e407335b` from `master`, then ran deploy setup through `gcloud`.
- The job used deploy credential source `gcp_artifact_json`, activated `artifact-registry-user@production-1386.iam.gserviceaccount.com`, set GCP project and region variables, built an image URI, and invoked `batch-yaml/workflow/deploy.sh`.
- The deploy step reached `Deploying workflow: model-training`, then failed with `PERMISSION_DENIED` because `workflows.workflows.get` was denied on the `model-training` workflow in `develop-1386`.
- The failure occurred while authenticated as the `production-1386` artifact-registry service account, suggesting the next useful debugging point is IAM/project identity alignment rather than runner startup or missing `gcloud`.

### Connectivity And App Switching

- Around 08:02-08:04, the user interacted with OpenVPN Connect from the menu bar and app window, including connect, disconnect confirmation, quitting/reopening via Dock/Raycast, and another connection attempt.
- The user opened macOS Control Center Wi-Fi and selected the known network `DQ_MR_5G`.
- The user entered a VPN username into OpenVPN multiple times, then tabbed into the secure field; secure input content is not retained.
- These connectivity actions happened between GitLab checks, so they appear related to restoring access to work resources or clearing VPN/network state.

### Orca, Discord, Personal Browsing, And LINE

- Orca was opened around 08:05 and 08:07. It showed worktree/project lists and agent rows, including an ITRD workspace with an active child-agent terminal line, but the user did not complete a visible command or workspace action.
- Discord `#general | 水源市場` was opened briefly. The captured input was mostly transient IME fragments/deletions and is not useful or safe to preserve as message content.
- Dia briefly switched through personal Steam checkout/profile/media pages. The user added a Steam item to cart and proceeded into checkout/profile views, but there is no retained purchase completion state.
- Spotify showed playback/window changes, Raycast was used to open apps, Parsec was briefly clicked, LINE was opened near the end with only list/search UI visible, and Finder briefly showed Downloads.
- At 08:09, the user returned to Dia on the `itrd / 資料組 / modeling` GitLab project page. The project page showed `Project ID: 389`, `17 Commits`, `2 Branches`, latest visible commit `e407335b`, and `Pipeline: Failed`.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-09T08-00-00Z/events.jsonl
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T07-50-00-JBuj-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T07-40-00-UhjH-10min-memory-summary.md