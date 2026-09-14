---
title: DQOP Deploy, iOS Sideloading, Course Selection
description: You moved across DQOP/TMS deployment follow-up, LiveContainer/iGameGod sideloading experiments, Discord coordination, and NUTC course selection. The DQOP portal deployment reached a healthy verified state, while iLoader remained blocked by Apple authentication before IPA or tweak loading.
applications: [com.hnc.Discord, com.stablyai.orca, jp.naver.line.mac, company.thebrowser.dia, com.apple.finder, com.apple.dock, com.apple.dock.helper, com.NeatDownloadManager, com.apple.mail, me.nabdev.iloader, com.raycast.macos, com.apple.controlcenter, com.apple.systempreferences, com.apple.AppStore, com.apple.loginwindow, com.apple.notificationcenterui, com.microsoft.VSCode]
---

## Memory summary

The user’s larger arc in this six-hour window split across three meaningful tracks: DQOP/TMS deployment follow-up, iOS LiveContainer/iGameGod sideloading experiments, and personal coordination/course-selection tasks. The DQOP work progressed from a merged `tms-admin` CronJob runtime MR into ArgoCD, Terraform, database, Secret Manager, and portal deployment follow-up; by the last DQOP state captured, Orca showed the portal deployment as healthy with ArgoCD, Kubernetes, GCLB, API health, and database checks passing. The user then reactivated the DQOP Orca task with additional Terraform/infra follow-up around an `itrd/devops/infra` merge request.

The LiveContainer/iGameGod work moved from research and binary inspection into an Orca-generated LiveContainer tweak package. The user created `gamegod-tweak.zip`, copied it into Downloads, transferred it to an iPad with AirDrop, and used iLoader 2.3.1 for LiveContainer+SideStore setup. iLoader showed LiveContainer+SideStore installation success at one point, but later login attempts failed with Apple authentication `HTTP status server error (503 Service Temporarily Unavailable)`, leaving the flow blocked before IPA import, tweak loading, or iGameGod runtime testing.

The non-development activity was also substantial. The user coordinated Discord conversations around agent architecture, social scheduling, hardware/MIDI buying, device pricing, and community moderation. They downloaded Infinity Blade community patch IPA files from a shared Drive folder, checked macOS/app update flows, and used the NUTC student system to add one course successfully; afterward the selected-course summary showed 2 courses totaling 5 credits.

### Relevant prior context

Earlier 2026-09-10 summaries before this window established that the DQOP/TMS `tms-admin` CronJob runtime work had already been implemented, pushed as `fix/tms-admin-cronjob-runtime`, and opened as GitLab MR `!3`. The prior state also tied DQOP manifest follow-up to `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/dqop/tms`.

Earlier summaries also showed the user had already been exploring LiveContainer, SideStore, iLoader, and iOS app-loading mechanics before the six-hour window. That made the later iGameGod binary inspection, tweak-package generation, and iPad transfer part of a continuing sideloading experiment rather than a new isolated task.

### Important non-obvious context about the user

- `/Users/miyago/Project/Active/ITRD/DQOP/TMS/tms-admin` - DQOP/TMS-ADMIN project path tied to the CronJob runtime MR.
- `DQOP / TMS / TMS-ADMIN` MR `!3` - GitLab MR titled `fix: 補齊 CronJob runtime 檔案`, shown merged during this window.
- `a3059375`, pipeline `#75138` - commit and passed pipeline shown before the DQOP MR merge.
- `/Users/miyago/Project/Active/ITRD/devops/argocd` - local ArgoCD workspace inspected in VS Code for DQOP manifests and env patterns.
- `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/dqop/portal/overlay/production/env/prod.env` - DQOP portal production env file visible as untracked.
- `/Users/miyago/Project/Active/ITRD/devops/argocd/k8s-yaml/dqop/arms/overlay/dqop/env/.env` - DQOP arms env file shown modified in VS Code.
- `portal:758b7cde`, `035ac057c`, `sha256:c6084ef...` - DQOP deployment/image identifiers shown in the completed Orca deployment summary.
- `/Users/miyago/Project/Backups/Archive/gamegod` - local archive/work area for iGameGod/LiveContainer work.
- `/Users/miyago/Project/Backups/Archive/gamegod/work/gamegod-livecontainer-20260910/output/iGameGod-LiveContainer-Tweaks` - generated LiveContainer tweak output folder.
- `gamegod-tweak.zip` - package created and AirDropped to the iPad from Downloads.
- `./Library/Frameworks/iGameGod/CustomOffsetPatcheriOSGodsCom.dylib` - inspected Mach-O dylib during the LiveContainer/iGameGod investigation.
- `iloader 2.3.1` - iLoader version used for LiveContainer+SideStore install/login attempts.
- `HTTP status server error (503 Service Temporarily Unavailable)` - blocking iLoader Apple authentication error.
- `Infinity Blade I - Community Patch v2.5.ipa` and `Infinity Blade II - Community Patch v2.5.ipa` - IPA files downloaded and completed through Neat Download Manager.
- `NUTC ePortal` / student management system - course add/drop flow where one add-course action succeeded and selected courses reached 2 courses / 5 credits.
- `#💠｜管理群`, `#📬｜審核表單回傳`, `#🔧｜cmd` - Discord moderation flow channels used for a member/application review.

## Recording summary

### DQOP/TMS And ArgoCD Deployment Work

The DQOP/TMS thread began with the user checking GitLab MR `!3` for `DQOP / TMS / TMS-ADMIN`, titled `fix: 補齊 CronJob runtime 檔案`. The MR showed a passed merge request pipeline and ready-to-merge state for commit `a3059375`, then later showed as merged. The user clicked through related `TMS-ADMIN` and `itrd/Argocd` pipeline/job pages, including a `deploy-manifest` job page.

The user used Orca to supervise the DQOP task `檢查image並掛上CronJob`. Earlier visible DQOP agent work included Docker/runtime image checks, moving a Bun housekeeping build command into `package.json` as `build:housekeeping`, and later deployment commands involving Terraform validation/plan/apply, local ArgoCD diffs, staged Kubernetes deployment changes, and ArgoCD hard refresh operations.

In VS Code, the user opened the ArgoCD workspace at `/Users/miyago/Project/Active/ITRD/devops/argocd`, navigated DQOP `portal` and `arms` folders, and inspected production env/config files. VS Code showed pending Source Control changes on branch text resembling `fix/api-doc-auto-sync-20260909*`. The user opened `prod.env`, `.env`, `.env.secret`, deployment, kustomization, service, ingress, backend config, and cronjob-related manifests. Secret values were visible only as env/secret-file context and are not retained.

The user typed guidance into Orca that the post-deploy internal database data could be cleared because it was lightweight, no further migration was needed, and connection/password material belonged in Secret Manager. By the final DQOP capture, Orca showed the portal deployment as completed and healthy: ArgoCD `Synced / Healthy`, Kubernetes deployment `1/1 ready`, GCLB `HEALTHY`, API health checks returning 200, a separate `portal` database and `portal_app` account on the shared Cloud SQL `dqop` instance, and a Secret Manager entry for the portal app password. The user then sent another short follow-up and the DQOP task returned from `Done` to `Working`, with a visible GitLab MR reference for `itrd/devops/infra` merge request `14`.

### LiveContainer, iGameGod, And iLoader

The user researched LiveContainer/IPA loading and inspected local iGameGod tweak artifacts under `/Users/miyago/Project/Backups/Archive/gamegod`. They used Yazi through the `y` wrapper, then ran local binary inspection commands including `file` and `otool -L` on `./Library/Frameworks/iGameGod/CustomOffsetPatcheriOSGodsCom.dylib`. The results identified the dylib as an arm64 Mach-O dynamic library with linked frameworks and `@rpath` entries, and the user pasted selected output into a ChatGPT research conversation.

The user then shifted the work into Orca with a task titled `改造 iGameGod deb 支援 LiveContainer | gamegod`. Orca later showed that task as completed, with output at `/Users/miyago/Project/Backups/Archive/gamegod/work/gamegod-livecontainer-20260910/output/iGameGod-LiveContainer-Tweaks`, containing `libloader.dylib` and `iGameGod.framework` for LiveContainer runtime tweak loading.

The user packaged that output into `gamegod-tweak.zip`, copied it into `/Users/miyago/Downloads`, and used Finder/AirDrop to send it to the user’s iPad. iLoader 2.3.1 was opened afterward. It showed LiveContainer+SideStore installation success at one point, but later attempts to login or continue the flow failed at Apple ID authentication. The user tried refreshing devices, relaunching iLoader through Raycast, selecting USB and network iPad entries, redownloading `iloader-darwin-universal.dmg`, opening the DMG, and relaunching iLoader again. The observed blocker remained an Apple GrandSlam authentication `503 Service Temporarily Unavailable` before IPA import, LiveContainer tweak import, or game behavior testing.

### Infinity Blade Downloads

The user searched for Infinity Blade downloads, navigated a shared Drive folder named `Game Downloads`, and opened folders for `Infinity Blade 1` and `Infinity Blade 2`. They selected community patch IPA folders and proceeded past large-file warnings. Neat Download Manager downloaded `Infinity Blade I - Community Patch v2.5.ipa` at about 605.2 MB and `Infinity Blade II - Community Patch v2.5.ipa` at about 1.0 GB; both were reported complete during the window. The user also browsed adjacent shared folders such as Infinity Blade 3, FX, Dungeons, modded IPAs, troubleshooting, and README-like material, with no additional completed download recorded.

### Discord, Communication, And Moderation

Discord activity covered several unrelated coordination threads. In `#💻｜技術交流`, the user discussed agent routing architecture, including model/provider boundaries and composing different harnesses. In `#general | 水源市場`, the user coordinated social scheduling around timing/travel and later joined casual device-pricing discussions. In `#和月房間` / `#儲物間`, they discussed MIDI controller choices and appeared to settle toward an ICON Artist 37 plus a sustain pedal, while treating bundled headphones, earplugs, and hub as unnecessary.

The user also performed a Discord moderation flow in the `卯咪卯的窩` server. They checked `#💠｜管理群`, briefly opened an external social/profile page for context, added a check reaction in `#📬｜審核表單回傳`, copied a Discord user ID, and used slash-command autocomplete in `#🔧｜cmd` for an `/accept-apply member` command. The final command outcome was not clearly captured.

### NUTC Course Selection

The user opened NUTC ePortal and reached the student management/course system. They navigated course add/drop pages, public course lookup pages, class listings, and graduation-progress views. In the NUTC course add/drop flow, the user confirmed one add-course action successfully; immediately afterward, the selected-course summary showed 2 selected courses totaling 5 credits. They continued comparing course availability, time information, department/year filters, and graduation requirements, with no further confirmed add/drop outcome retained.

### System Updates And Incidental Activity

The user checked App Store updates and System Settings Software Update. App Store showed updates in progress and a prompt related to closing Telegram to complete an update. System Settings showed macOS 27 and Command Line Tools for Xcode 27.0 available, and the user clicked an update action that produced a password prompt. Later, Notification Center showed an imminent restart notification for installing updates, which the user dismissed. No completed reboot or update installation was captured.

The user also switched through Finder, Mail, LINE, Dia media tabs, YouTube, and ChatGPT throughout the window. These activities mostly supported the active threads above or were casual browsing, with no additional durable technical outcome captured.

## Citations

- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T06-00-00-Osbc-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T06-10-00-HDqp-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T06-20-00-VjpP-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T06-30-00-AUed-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T06-50-00-SAbb-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T07-10-00-ysWg-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T07-20-00-idiy-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T07-30-00-NxQH-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T07-40-00-wJiG-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T07-50-00-MVzc-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-00-00-wxOa-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-10-00-vUMW-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-20-00-KUgx-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-30-00-Arst-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-40-00-pkkD-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T08-50-00-dMGK-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T09-00-00-LglR-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T09-10-00-MSiM-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T09-20-00-rOkg-10min-memory-summary.md
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T09-40-00-yHNd-10min-memory-summary.md