---
title: NUTC Course Add And Schedule Checks
description: You worked in the NUTC student course system, confirmed one add-course action, then compared course and graduation-progress pages. You later switched briefly through Orca, Discord, media tabs, and LINE without a new technical outcome.
applications: [company.thebrowser.dia, com.stablyai.orca, com.hnc.Discord, jp.naver.line.mac]
---

## Memory summary

The user continued a school course-selection flow in Dia. The NUTC student system showed a successful add-course confirmation around 09:20, after which the selected-course summary showed 2 courses totaling 5 credits. The user then browsed add/drop, class course listings, and graduation-progress pages, apparently comparing course availability, times, and graduation requirements. Near the end of the window, the user briefly checked Orca, Discord, music/video browser tabs, and LINE; those switches did not show a durable task result.

### Relevant prior context

The immediately preceding 09:10 Skysight summary recorded that the user had pivoted from DQOP deployment follow-up into NUTC ePortal and course/add-drop lookup. It also established that the DQOP Orca task `檢查image並掛上CronJob` was still active in the background before this 09:20 window.

### Important non-obvious context about the user

- `NUTC ePortal` / NUTC student management system: the active school portal flow for course add/drop, course lookup, and graduation-progress checks.
- `115(上)`: the semester visible across the course-information and add/drop pages.
- `四技-資訊工程系`: the department filter used while browsing add/drop options.
- `com.stablyai.orca`: briefly visible with active project/worktree state after the school-course browsing; no new Orca task outcome was captured.
- `company.thebrowser.dia`: main browser used for the NUTC portal/course workflow.

## Recording summary

### NUTC Course Selection And Verification

- The window opened in Dia on NUTC public course information pages. The user used the subject lookup tab, typed a Japanese-course query, saw an initial “subject name not found” style alert, then selected a more specific Japanese-course option from suggestions.
- The public course-info result showed 2 matching course rows with shared timing and teacher information. The user highlighted the course name and switched back to the authenticated student add/drop tab.
- In the authenticated add/drop page, the user clicked an add-course action. The system displayed a confirmation dialog, the user accepted it, and the next alert reported the add was successful.
- Immediately after the confirmation, the selected-course page showed 2 selected courses totaling 5 credits. This is the strongest captured state change in the window.
- The user returned to the add-course search view, selected the information-engineering department filter, and compared several class/course listings across year/class options.
- The user opened the graduation-progress page, viewed course-standard/progress information, then returned to course add/drop and public course listings. The progress view showed graduation requirements and progress metrics, but personal identifiers and detailed page text are omitted.
- The user searched for NUTC day-division course information and opened public course-information pages for day-division class listings. They browsed multiple information-engineering year/class options, likely comparing times and available classes.

### Later App Switching

- After the course checks, the user briefly switched through Orca. Orca showed the same broader workspace board and a background DQOP-related task, but no new technical action or completion was captured in this window.
- The user briefly visited Discord channels and then returned to Dia browser tabs, including music/video and iLoader-related tabs. Message contents, web page contents, and media contents are not retained.
- LINE became active briefly near the end of the captured activity, with no retained message content.
- The segment metadata covers 09:20 to 09:30 with 280 events and 19 suppressed events; meaningful activity was concentrated before about 09:27.

## Citations

- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-10T09-20-00Z/events.jsonl
- /Users/miyago/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-09-10T09-20-00Z/metadata.json
- /Users/miyago/.codex/memories/extensions/skysight/resources/2026-09-10T09-10-00-MSiM-10min-memory-summary.md