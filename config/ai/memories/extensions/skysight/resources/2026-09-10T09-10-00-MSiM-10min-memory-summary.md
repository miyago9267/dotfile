---
title: DQOP Deploy Follow-Up And Course Lookup
description: You inspected ITRD ArgoCD env files and steered an Orca DQOP deployment task around database reset and secret handling. You then logged into NUTC ePortal and searched course/add-drop information.
applications: [company.thebrowser.dia, com.stablyai.orca, com.apple.systempreferences, com.microsoft.VSCode, com.hnc.Discord, com.raycast.macos, jp.naver.line.mac]
---

## Memory summary

The user continued the DQOP/TMS deployment follow-up. They inspected local ArgoCD manifests in VS Code under `/Users/miyago/Project/Active/ITRD/devops/argocd`, especially DQOP `portal` and `arms` env/config paths, while Orca showed an active DQOP task titled `檢查image並掛上CronJob` running infrastructure and deployment-related checks. The user then typed guidance into Orca indicating that post-deploy internal databases could be cleared because the internal data is lightweight, that no further migration was needed, and that connection/password material should live in Secret Manager.

The user then pivoted to personal/school browsing. In Dia they opened NUTC ePortal, reached the student management system, navigated to course add/drop pages, then opened a new tab and searched for NUTC continuing-education course information and timetable/course pages. Login identifiers, passwords, captcha values, and page contents are not retained.

### Relevant prior context

The immediately preceding 09:00 summary recorded that the DQOP Orca task `檢查image並掛上CronJob` was still active while the user mainly handled Discord moderation. The 08:50 summary established the DQOP/TMS `tms-admin` CronJob runtime MR had been merged and that the user was checking related GitLab pipeline/job state plus local ArgoCD manifests in `/Users/miyago/Project/Active/ITRD/devops/argocd`.

Earlier DQOP summaries established that the CronJob work had moved from runtime packaging into ArgoCD manifest and deployment follow-up, with Cloud SQL/Postgres/config questions still relevant. A prior 2026-09-09 summary also showed the user had previously used NUTC ePortal and student-system course/add-drop related pages.

### Important non-obvious context about the user

- `/Users/miyago/Project/Active/ITRD/devops/argocd`: VS Code workspace used for ITRD ArgoCD/Kubernetes manifest checks.
- `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/dqop/portal/overlay/production/env/prod.env`: DQOP portal production env file opened as an untracked file.
- `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/dqop/arms/overlay/dqop/env/.env`: DQOP arms env file edited or left modified in VS Code.
- `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/dqop/arms/overlay/production/env/.env.secret`: production secret env file opened for reference; secret values are not retained.
- `gke_production-1386_asia-east1_production-cluster`: Kubernetes context visible in Orca’s DQOP deployment command text.
- `argocd` namespace and `portal` ArgoCD application: visible in an Orca command that hard-refreshed the application.
- `NUTC ePortal` / student management system: school portal flow used for add/drop and course information lookup.
- `com.stablyai.orca`, `com.microsoft.VSCode`, `company.thebrowser.dia`: main apps for this window’s technical follow-up and course lookup.

## Recording summary

### DQOP And ArgoCD Follow-Up

- At the start of the window, Dia showed a personal YouTube tab, then the user switched to Orca.
- Orca’s board showed prior completed technical cards and the active DQOP row `檢查image並掛上CronJob`. The active row later displayed commands related to `terraform validate`, `terraform plan`, applying a saved plan for a dedicated DB, reading a secret through `gcloud secrets versions access` with the secret name redacted, applying a patch, checking Git diffs, staging `k8s-yaml/dqop/portal/base/deployment.yaml`, and hard-refreshing the ArgoCD `portal` application through `kubectl`.
- The user switched to System Settings briefly on Software Update, then to VS Code.
- VS Code showed workspace `base-itrd-project (Workspace)` rooted around `/Users/miyago/Project/Active/ITRD/devops/argocd`. The user had `kustomization.yaml` open at `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/official-website/magiresort/overlay/production/kustomization.yaml`.
- The user clicked through DQOP manifest folders under `k8s-yaml/dqop`, including `portal`, `arms`, `overlay`, `production`, `stage`, `base`, `env`, and files such as `prod.env`, `.env.secret`, `.env`, `backend-config.yaml`, `deployment.yaml`, `kustomization.yaml`, `service.yaml`, `cronjobs.yaml`, `deployment-patch.yaml`, `ingress-patch.yaml`, and `ingress.yaml`.
- VS Code indicated 4 pending Source Control changes. The visible DQOP `portal/overlay/production/env/prod.env` was untracked, and `dqop/arms/overlay/dqop/env/.env` became modified after the user inserted blank lines or adjusted line positions around lines 63-69. Exact env contents and any secret values are omitted.
- The user returned to Orca and typed a fragmented but clear-enough note into the DQOP task: internal databases could be cleared after deployment because internal data is lightweight, there was no need for further migration, manual handling was enough, and connection/password information should go into Secret Manager. IME capture produced repeated partial submissions, so exact wording is not durable.
- The event stream did not capture a final DQOP completion result within this 10-minute window.

### Communication And App Switching

- The user briefly opened Discord channels in the `卯咪卯的窩` server, including `#🌐｜大廳` and `#💻｜技術交流`. Message contents are not retained.
- Raycast was used to switch to LINE. LINE opened briefly, with no retained message content.
- The user returned through Orca and Dia several times while the DQOP worker remained visible as working.

### NUTC ePortal And Course Lookup

- After a short personal YouTube browsing sequence in Dia, the user opened a new tab and searched for NUTC ePortal.
- Dia showed the NUTC ePortal login page. Saved account/password fields and a captcha-like short input were visible, but identifiers and values are omitted.
- The user reached a student management system page, clicked through system announcements and course add/drop pages, and interacted with the course add/drop UI for about 40 seconds. The recording does not establish a completed add/drop transaction.
- The user opened another new tab, searched for NUTC course information, refined the query toward continuing-education course information, opened course timetable/query pages, and clicked course-information/timetable navigation entries near the end of the window.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-10T09-10-00Z/events.jsonl
- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-10T09-10-00Z/metadata.json
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T09-00-00-LglR-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-50-00-dMGK-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-09T05-30-00-LmMG-10min-memory-summary.md