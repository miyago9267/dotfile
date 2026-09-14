---
title: GCP Billing And Infra Checks
description: You reviewed Google AI Studio usage, GCP billing reports, and several GCP infrastructure pages. The work moved from API/spend checks into Compute Engine, GKE, Batch, and Cloud Scheduler views for production and develop projects.
applications: [company.thebrowser.dia]
---

## Memory summary

The user spent this window in Dia inspecting Google AI Studio and Google Cloud Console state. The activity started from AI Studio API keys and spend/billing pages, moved through a GCP billing account’s reports and commitments views, then pivoted into Compute Engine, GKE, Batch, and Cloud Scheduler resources. The final visible state was the Cloud Scheduler jobs page for `develop-1386`, after searches through GCP product pages.

### Relevant prior context

The immediately preceding available Skysight summary showed the user investigating an internal GitLab deploy failure in `itrd / 資料組 / modeling`. That failure involved a GCP permission error while deploying workflow `model-training` in `develop-1386`, with cross-project context involving `production-1386`; this helps explain why the user continued inspecting GCP project and resource state in this window.

### Important non-obvious context about the user

- `production-1386`: GCP project repeatedly visible in AI Studio API key, spend, billing, and Compute Engine contexts.
- `develop-1386`: GCP project used after switching into Compute Engine/GKE/Batch/Cloud Scheduler views.
- `Google AI Studio`: the user inspected API keys, usage, spend, and billing; visible key labels included `agent-pms`, `pms`, `Production-Key`, and `dq-agent`, but no full key values are retained.
- `Total cost $6.19`: visible AI Studio project spend value selected on the Spend page.
- `Total cost $856.53`: visible AI Studio billing total selected on the Billing page.
- `standard-cluster`: GKE cluster opened under `develop-1386`, region/zone context visible as `asia-east1-c`.
- `Cloud Scheduler`: final resource area reached through GCP search after passing through Batch jobs.

## Recording summary

### Google AI Studio Review

- At 08:20, the user opened a new Dia tab and navigated to Google AI Studio.
- The API keys page loaded for `production-1386`. The table showed multiple API key rows associated with projects including `production-1386` and `develop-1386`; the user dragged/selected around project and key labels, likely trying to read or copy metadata.
- The user changed grouping or navigation from API keys into Usage, Billing, and Spend.
- On the Spend page for `production-1386`, the selected chart text showed total cost `$6.19`.
- On the Billing page, the user selected chart text showing total cost `$856.53`.

### GCP Billing Account Reports

- Around 08:21, the user briefly switched through a Gmail tab but immediately returned to a Google Cloud Billing report.
- In Google Cloud Console, the user opened the billing account page, reports, tabular reports, and commitments/commitment analysis views.
- The billing report context used a custom July 2026 date range and project `production-1386`.
- The user clicked through report controls and “show more/show less” areas, then returned to the tabular billing report view. No durable export or edit was visible.

### Compute, GKE, Batch, And Scheduler

- Around 08:26, the user left billing reports and opened Compute Engine for `production-1386`, then Compute overview and VM instances.
- The user interacted with project selection or project context, moving into `develop-1386`.
- They opened VM observability, selected CPU, then clicked through instance templates and Compute overview.
- The user navigated into Kubernetes Engine, opened the GKE cluster list, selected `standard-cluster`, and opened the cluster nodes view.
- From the GKE nodes page, the user used GCP search/product navigation, first typing transient fragments, then reaching Batch jobs for `develop-1386`.
- In Batch jobs, the user searched again and selected Cloud Scheduler. The final event at 08:29:55 showed the Cloud Scheduler jobs page for `develop-1386`.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-09T08-20-00Z/events.jsonl
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T08-00-00-gXXv-10min-memory-summary.md