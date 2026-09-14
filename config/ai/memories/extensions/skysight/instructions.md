# Skysight Memory Instructions

Skysight 是 memory extension，提供使用者近期 activity context 的 chronological
10-minute 與 6-hour summaries；內容來自 background 執行的 rolling local event
stream process。

生成 phase2 memories 時，使用本 instructions file 旁 resources folder 中的相關
summaries，作為使用者近期 activity 的 evidence。Resources 可能包含 development、
meetings、communication、planning、research 與 operational tasks。對該 folder 做
Grep，找出和目前要 consolidation 的 memory 有關的 material。

每份 resource 的 YAML frontmatter 是 presentation metadata。phase2 memory
consolidation 時忽略它，使用 Markdown body 作為 evidence。

Skysight 要納入的重點：

- 只有在 `Important non-obvious context about the user` sections 提供足夠支持且
  可重用的 context 時，才選擇性放進 `User Profile`；例如 recurring preference、
  stable workflow 或 repeated collaborator/tool pattern。不要把單次觀察到的
  meeting、trip、app visit 或短期 logistics 升格成 durable profile fact。
- 只有 chronological details 能實質支援 ongoing task、durable decision、
  meaningful blocker、reusable workflow 或 likely follow-up 時，才放進
  `MEMORY.md`。優先保留精簡 task arc，不要保存每個 window-level action。
- 用 10-minute summaries 恢復 immediate context，用 6-hour summaries 恢復 broader
  arcs。兩者描述同一 activity 時，除非 continuity 需要細節，優先採用較高層級的
  account。
- Skysight resources 是 rollout memories 的 observed activity 補充；不會自動比
  其他 evidence 更重要，也不需要為 incidental activity 建立 synthetic entries。

Summary 中凡是 derived from this 的資訊，後面加上 `[skysight memory]` tag。

## Folder structure

- resources/*.md
  - Skysight memories：event streams 的 Markdown summaries，分成 10 minute/6h
    chunks。File format：`YYYY-MM-DDTHH-MM-SS-{4_alpha_chars}-10min-{slug_description}.md`
    或 `YYYY-MM-DDTHH-MM-SS-{4_alpha_chars}-6h-{slug_description}.md`。
