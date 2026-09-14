---
name: officecli
description: 使用 officecli CLI 工具建立、分析、校閱與修改 Office 文件（.docx、.xlsx、.pptx）。使用者要建立、檢查格式、找問題、加圖表或修改 Office 文件時使用。
---

# officecli 文件工具

適合 AI 使用的 .docx、.xlsx、.pptx CLI。單一 binary，沒有 dependencies，也不需要安裝 Office。

## 安裝

如果尚未安裝 `officecli`：

```bash
# macOS / Linux
curl -fsSL https://d.officecli.ai/install.sh | bash

# Windows (PowerShell)
irm https://d.officecli.ai/install.ps1 | iex
```

用 `officecli --version` 驗證。安裝後仍找不到時，開新的 terminal。

---

## 策略

**L1（read）→ L2（DOM edit）→ L3（raw XML）**。優先使用較高層級；需要結構化輸出時加上 `--json`。

**開始文件工作前，先檢查本檔案底部的 Specialized Skills**。Fundraising deck、academic paper、financial model、dashboard 與 Morph animation 必須先載入對應 skill；只執行一次 `load_skill`，再繼續工作。

---

## Help System（重要）

**不確定 property name、value format 或 command syntax 時，一律先跑 help，不要猜。** 一次 help query 比猜錯、失敗、重試的循環可靠。

`officecli help` ≡ `officecli --help`；`officecli <cmd> --help` ≡ `officecli help <cmd>`，兩者內容相同。

```bash
officecli help                                  # All commands + global options + schema entry points
officecli help docx                             # List all docx elements
officecli help docx paragraph                   # Full schema: properties, aliases, examples, readbacks
officecli help docx set paragraph               # Verb-filtered: only props usable with `set`
officecli help docx paragraph --json            # Structured schema (machine-readable)
```

Format aliases：`word`→`docx`、`excel`→`xlsx`、`ppt`/`powerpoint`→`pptx`。Verbs：`add`、`set`、`get`、`query`、`remove`。MCP 透過單一 `command` string param 提供相同 schema：`{"command":"help docx paragraph"}`。這不是 structured `{"format":...,"type":...}` object；MCP tool 只有一個 `command` param，並原樣傳給 CLI verb。

---

## 效能：Resident Mode

**每個 command 第一次存取時都會自動啟動 resident**（60s idle timeout），會自動避免 file-lock conflict。較長的 session（12min idle）仍建議明確使用 `open`/`close`：
```bash
officecli open report.docx       # explicitly keep in memory
officecli set report.docx ...    # no file I/O overhead
officecli close report.docx      # save and release
```

停用 auto-start：`OFFICECLI_NO_AUTO_RESIDENT=1`。

**只在離開 officecli 的邊界 flush。** officecli 自己的 reads（`get`/`query`/`view`/`dump`）永遠看得到最新 edits，所以 workflow 中間不用 save。只有在 **non-officecli program 要讀檔案前**，才執行 `save`（保留 resident）或 `close`（flush + release）；例如 python-docx/openpyxl、Word、renderer 或 delivery/upload。（Idle session 會在數秒內 auto-flush；`OFFICECLI_RESIDENT_FLUSH=each` 會讓每次 mutation return 前都 flush。）

---

## 快速開始

**PPT：**
```bash
officecli create slides.pptx
officecli add slides.pptx / --type slide --prop title="Q4 Report" --prop background=1A1A2E
officecli add slides.pptx '/slide[1]' --type shape --prop text="Revenue grew 25%" --prop x=2cm --prop y=5cm --prop font=Arial --prop size=24 --prop color=FFFFFF
```

**Word：**
```bash
officecli create report.docx
officecli add report.docx /body --type paragraph --prop text="Executive Summary" --prop style=Heading1
officecli add report.docx /body --type paragraph --prop text="Revenue increased by 25% year-over-year."
```

**Excel：**
```bash
officecli create data.xlsx
officecli set data.xlsx /Sheet1/A1 --prop value="Name" --prop bold=true
officecli set data.xlsx /Sheet1/A2 --prop value="Alice"
```

---

## L1：建立、讀取與檢查

```bash
officecli create <file>               # Create blank .docx/.xlsx/.pptx (type from extension)
officecli view <file> <mode>          # outline | stats | issues | text | annotated | html
officecli get <file> <path> --depth N # Get a node and its children [--json]
officecli query <file> <selector>     # CSS-like query
officecli validate <file>             # Validate against OpenXML schema
```

### view modes

| Mode | 說明 | 常用 flags |
|------|-------------|-------------|
| `outline` | 文件結構 | |
| `stats` | 統計資料（頁數、字數、shape） | |
| `issues` | 格式、內容與結構問題 | `--type format\|content\|structure`、`--limit N` |
| `text` | 純文字擷取 | `--start N --end N`、`--max-lines N` |
| `annotated` | 附格式標註的文字 | |
| `html` | 靜態 HTML snapshot；與 `watch` 使用相同 renderer，不需要 server | `--browser`、`--page N`（docx）、`--start N --end N`（pptx） |
| `screenshot` / `svg` / `pdf` / `forms` | 透過 headless browser 產生 PNG／pptx slide 的 SVG／exporter plugin 產生 PDF／format-handler plugin 產生 form-fields JSON | `-o`、`--screenshot-width/-height`、pptx `--grid N` |

一次性 snapshot（CI artifact、封存、diff）使用 `view html`；需要 live refresh 或在 browser 點選時使用 `watch`。

### get

可用 element localName 指定任何 XML path。用 `--depth N` 展開 children；需要結構化輸出時加 `--json`。預設文字輸出方便 grep：`path (type) "text" key=val key=val ...`

```bash
officecli get report.docx '/body/p[3]' --depth 2 --json
officecli get slides.pptx '/slide[1]' --depth 1          # list all shapes on slide 1
officecli get data.xlsx '/Sheet1/B2' --json
```

### Stable ID 尋址

有 stable ID 的 elements 會回傳 `@attr=value` path，而非 positional index。多步驟 workflow 優先使用這種 path；insert/delete 會讓 positional index 位移，stable ID 不會。

```
/slide[1]/shape[@id=550950021]                    # PPT shape
/slide[1]/table[@id=1388430425]/tr[1]/tc[2]       # PPT table
/body/p[@paraId=1A2B3C4D]                         # Word paragraph
/comments/comment[@commentId=1]                    # Word comment
```

PPT 也接受 `@name=`（例如 `shape[@name=Title 1]`），並能辨識 morph 的 `!!` prefix。沒有 stable ID 的 elements（slide、run、tr/tc、row）會 fallback 到 positional index。

### query

支援 CSS-like selector：`[attr=value]`、`[attr!=value]`、`[attr~=text]`、`[attr>=value]`、`[attr<=value]`、`:contains("text")`、`:empty`、`:has(formula)`、`:no-alt`。`query`/`set`/`remove` 都支援 Boolean `and`/`or`：`cell[value>5000 or value<100]`、`cell[(type=Number or type=Date) and value>0]`。Excel 可用欄名查詢列：`Sheet1!row[Salary>5000]`。`set` 接受 selector 與 Excel-native path，行為和 `get`/`query` 一致。`set`/`remove` 拒絕沒有 scope 的 bare selector。

```bash
officecli query report.docx 'paragraph[style=Normal] > run[font!=Arial]'
officecli query slides.pptx 'shape[fill=FF0000]'
```

---

## Watch 與互動選取

Live HTML preview 會在每次檔案變更時自動 refresh。可以在 browser click、shift-click 或 box-drag 選取 shapes，再由 CLI 讀取目前 browser selection 並套用操作。

```bash
officecli watch <file> [--port N]      # Start preview server (default port 26315)
officecli unwatch <file>               # Stop
officecli goto <file> <path>           # Scroll watching browser(s) to element (docx: p / table / tr / tc)
```

開啟輸出的 `http://localhost:N` URL。click 可選取，shift/cmd/ctrl+click 可多選，從空白處拖曳可框選。PPT/Word 使用藍色外框；Excel 使用原生風格的綠色選取（double-click cell 可 inline edit；拖曳 chart 可 reposition）。

### `get <file> selected` — 讀取使用者點選的內容

```bash
officecli get <file> selected [--json]
```

回傳目前選取內容的 DocumentNodes。沒有選取內容時回傳空結果；沒有執行 watch 時 exit code != 0。

```bash
# 使用者在 browser 點選 shapes，再要求「把這些變成紅色」
PATHS=$(officecli get deck.pptx selected --json | jq -r '.data.Results[].path')
for p in $PATHS; do officecli set deck.pptx "$p" --prop fill=FF0000; done
```

### 重要特性

- **Selection 會跨檔案編輯保留。** Paths 使用 stable `@id=` 格式。
- **所有連線中的 browser 共用一個 selection。** 採 Last-write-wins。
- **同一檔案只能 single-watch。** 一個檔案同時只能有一個 watch process。
- **Group shapes 會整組選取。** v1 不支援深入選取 group 的個別 children。
- **支援範圍：** `.pptx` 的 shapes/pictures/tables/charts/connectors/groups；`.docx` 的 top-level paragraphs 與 tables。Inherited layout/master decorations 和 Word nested elements（table cells、run-level）無法尋址。**`.xlsx` 不會產生 `data-path`**，所以 xlsx 的 `mark`/`selection` 永遠解析成 `stale=true`（v2 candidate）。

### Marks — 等待 review 的編輯提案

變更需要在人為套用到檔案前 review 時使用 `mark`。Marks 只存在 watch process；另一個 `set` pipeline 會套用已接受的 marks。一次性變更直接使用 `set`；要建立永久檔案註記則使用 `add --type comment`（Word native）。

```bash
officecli mark <file> <path> [--prop find=... color=... note=... tofix=... regex=true] [--json]
officecli unmark <file> [--path <p> | --all] [--json]
officecli get-marks <file> [--json]
```

Props：`find`（literal；`regex=true` 時為 regex；raw form `find='r"[abc]"'`）、`color`（hex／`rgb(...)`／22 個 named whitelist）、`note`、`tofix`（驅動 apply pipeline）。**Path** 必須使用 watch HTML 產生的 `data-path` 格式；完整 pipeline 見 subskills。

---

## L2：DOM Operations

### set — 修改 properties

```bash
officecli set <file> <path> --prop key=value [--prop ...]
```

透過 element path（用 `get --depth N` 找到）可以設定 **任何 XML attribute**，包括目前不存在的 attribute。沒有 `find=` 時，`set` 會把格式套用到整個 element。

**Value formats：**

| Type | 格式 | 範例 |
|------|--------|---------|
| Colors | Hex（可含或不含 `#`）、named、RGB、theme | `FF0000`、`#FF0000`、`red`、`rgb(255,0,0)`、`accent1`..`accent6` |
| Spacing | 帶 unit 的數值 | `12pt`、`0.5cm`、`1.5x`、`150%` |
| Dimensions | EMU 或帶 suffix 的數值 | `914400`、`2.54cm`、`1in`、`72pt`、`96px` |

**Dotted-attr aliases**：shape/run/paragraph/table/row/cell/section/styles 都接受 `font.<attr>` 形式，例如 `--prop font.color=red --prop font.bold=true --prop font.size=14pt`。完整清單執行 `officecli help <fmt> <element>`。

### find — 格式化或取代符合的文字

在 `set` 使用 top-level `--find`／`--replace`（`query` 使用 `--find`）。Legacy `--prop find=X` 仍可用，但會輸出提示。

```bash
# Format matched text (auto-splits runs)
officecli set doc.docx '/body/p[1]' --find weather --prop bold=true --prop color=red

# Regex matching (regex= still a prop flag)
officecli set doc.docx '/body/p[1]' --find '\d+%' --prop regex=true --prop color=red

# Replace text (use `/` for whole-document scope)
officecli set doc.docx / --find draft --replace final

# docx: tracked Find&Replace
officecli set doc.docx / --find draft --replace final --prop revision.author=Alice

# PPT — same syntax, different paths
officecli set slides.pptx / --find draft --replace final
```

**Path 會控制搜尋範圍：** `/` = 整份文件，`/body/p[1]` 或 `/slide[N]/shape[M]` = 指定 element，`/header[1]`／`/footer[1]` = headers/footers。

**注意：**
- 預設區分大小寫。不分大小寫使用：`--prop 'find=(?i)error' --prop regex=true`
- Matches 可以跨越 run boundary。
- 沒有 match = 靜默成功；`--json` 會包含 `"matched": N`。
- **Excel：** 只支援 `find` + `replace`，不支援 find + format props。

### add — 新增 elements 或 clone

```bash
officecli add <file> <parent> --type <type> [--prop ...]
officecli add <file> <parent> --type <type> --after <path> [--prop ...]   # insert after anchor
officecli add <file> <parent> --type <type> --before <path> [--prop ...]  # insert before anchor
officecli add <file> <parent> --type <type> --index N [--prop ...]        # 0-based position (legacy)
officecli add <file> <parent> --from <path>                               # clone existing element
```

`--after`、`--before`、`--index` 互斥。沒有 position flag = append 到結尾。

**Element types（含 aliases）：**

| Format | 支援的 types |
|--------|-------|
| **pptx** | slide (incl. hidden), shape (font.latin/ea/cs, direction=rtl, underline.color, highlight=COLOR (Add/Set/Get/HTML preview), effective.X+effective.X.src; arrow alias for rightArrow; slideMaster/slideLayout typed add/set/remove), picture (SVG, brightness/contrast/glow/shadow, rotation, link, tooltip), chart (direction=rtl, pieOfPie, barOfPie, axisLine/gridline per-attr setters, animation+chartBuild=byCategory|bySeries, line dropLines/hiLowLines/upDownBars, anchor=x,y,w,h shorthand), table (cell direction=rtl, fill/background, built-in PowerPoint style catalogue, /col[C] get + swap/copyFrom, row/col Move/CopyFrom), row (tr), connector (from/to accept full-path `@name=`/`@id=` forms — bare `@name=Foo` is rejected, must be `/slide[N]/shape[@name=Foo]` — startshape/endshape SetByPath; edge-to-edge anchoring by default, fromSide/toSide to force an edge, fromIdx/toIdx for raw cxn index), group (link, tooltip, deep walk by get/query/add/remove, ungroup=true dissolves back to slide-absolute), align/distribute (targets= accepts shape[@id=N] paths, not just positional), video/audio (loop, autoStart alias), equation, notes (direction=rtl, lang), comment (legacy + modern p188 threaded round-trip), animation (15 emphasis + 16 exit presets, multi-effect chains, motion-path presets, repeat/restart/autoReverse, chart animations), transition (12 p15 presets + morph/p14), paragraph (para), run, zoom, ole (preview=, full dump round-trip via add-part+raw-set), placeholder (phType=...), model3d (rotation=ax,ay,az; full dump round-trip), smartart (dump round-trip via add-part), diagram (add-only mermaid → native shapes or rendered image, `--type diagram`/`flowchart`). |
| **docx** | paragraph (direction/font.latin/ea/cs, bold.cs/italic.cs/size.cs, lang.latin/ea/cs, wordWrap, framePr.\*, tabs shorthand), run (lang slots, direction, underline.color, position half-pts, **revision.type=ins\|del\|format\|moveFrom\|moveTo + revision.action=accept\|reject** with .author/.date — bare `@author=`/`@type=` selector on `set /revision[...]` for filtered accept/reject, but `query 'revision[...]'` needs the dotted `revision.author=`/`revision.type=` form; move+revision is run-level paths only, not paragraph-level; **range=START:END** on a paragraph/shape path formats a char span by explicit 0-based half-open offset instead of addressing a run — the offset sibling of find=), table (direction=rtl, hMerge, cantSplit on row/nowrap on cell (both add+set), **virtual column ops**: add/remove/move/copyfrom on /body/tbl[N]/col), row (tr), cell (td), image, header/footer (direction), section (pageNumFmt full enum, direction=rtl, rtlGutter, pgBorders=box), bookmark, comment, footnote, endnote, formfield, sdt, chart, equation, field (28 types), hyperlink, style (direction, indents, pbdr, lineSpacing on Add/Set), toc, watermark, break, ole, **num/abstractNum/lvl**, **tab**, **textbox/shape** (add-mostly — Get returns raw XML preview only, no structured readback; Set is limited to width/height/geometry/fill/line.\*; position is `anchor.x`/`anchor.y` not bare x/y; **textbox-only** `textDirection`/rotation/gradient/shadow — docx shape itself has neither rotation nor gradient), embedded **OLE round-trip on dump→batch**, **diagram** (add-only mermaid → native shapes or rendered image, `--type diagram`/`flowchart`, no x/y at add-time — reposition via `set /body/group[N]`). docDefaults.rtl, autoHyphenation, `get /` exposes locale + /comments /footnotes /endnotes. `create --minimal` for raw OOXML scaffolding. |
| **xlsx** | sheet (visible/hidden/veryHidden, print margins, printTitleRows/Cols, rightToLeft sheetView, cascade-aware rename), row (c{N}= cell-content shorthand; add accepts --from /Sheet/col[L]; formula-ref rewrite on insert), col (formula-ref rewrite, named-range follow on move), cell (type=richtext+runs, merge=range/sweep, direction=rtl, phonetic; **--shift left\|up on remove, shift=right\|down on add** — Excel UI dialog parity; formula auto-detect; OFFSET/INDIRECT in calc), chart (per-axis RTL/title, anchor=x,y,w,h, pareto), image (SVG), comment (direction=rtl), table (listobject), namedrange (definedname, volatile, `[@name=X]`; formula-body inlined at parse), pivottable (cache CoW + cross-pivot sharing, labelFilter=field:type:value add-time-only, topN=integer add-time-only, fillDownLabels is an alias of repeatLabels not a separate feature, calculatedField), sparkline, validation, autofilter, shape, textbox, CF (databar/colorscale/iconset/formulacf/cellIs/topN/aboveAverage), ole, csv. Query supports `merge`/`mergedrange`. Workbook: password. Shape selector enumerates leaves inside grpSp. |

### Pivot tables (xlsx)

```bash
officecli add data.xlsx /Sheet1 --type pivottable \
  --prop source="Sheet1!A1:E100" --prop rows=Region,Category \
  --prop cols=Year --prop values="Sales:sum,Qty:count" \
  --prop grandTotals=rows --prop subtotals=off --prop sort=asc
```

Key props：`rows`、`cols`、`values`（Field:func[:showDataAs]）、`filters`、`source`、`position`、`layout`（compact/outline/tabular）、`repeatLabels`、`blankRows`、`aggregate`、`showDataAs`（percent_of_total/row/col、running_total）、`grandTotals`、`subtotals`、`sort`。Aggregators：sum、count、average、max、min、product、stdDev、stdDevp、var、varp、countNums。Date columns 會自動分組。完整 schema 執行 `officecli help xlsx pivottable`。

### 文件層級 properties（所有 formats）

```bash
officecli set doc.docx / --prop docDefaults.font=Arial --prop docDefaults.fontSize=11pt
officecli set doc.docx / --prop protection=forms --prop evenAndOddHeaders=true
officecli set data.xlsx / --prop calc.mode=manual --prop calc.refMode=r1c1
officecli set slides.pptx / --prop defaultFont=Arial --prop show.loop=true --prop print.what=handouts
```

所有 document-level properties（docDefaults、docGrid、CJK spacing、calc、print、show、theme、extended）執行 `officecli help <format> /` 查詢。

### Sort（xlsx）

```bash
officecli set data.xlsx /Sheet1 --prop sort="C desc" --prop sortHeader=true
officecli set data.xlsx '/Sheet1/A1:D100' --prop sort="A asc" --prop sortHeader=true
```

Format：`COL DIR[, COL DIR ...]`。含 merged cells 或 formulas 的 ranges 會被拒絕。Sidecar metadata（hyperlinks、comments、conditional formatting、drawings）會自動跟隨 rows。

### 以文字錨點插入（`--after find:X`／`--before find:X`）

用 paragraph 內的文字 match 找到插入點。Inline types（run、picture、hyperlink）會插入 paragraph 內；block types（table、paragraph）會自動切開 paragraph。PPT 只支援 inline。

```bash
# Word：在符合文字後插入 inline run
officecli add doc.docx '/body/p[1]' --type run --after find:weather --prop text=" (sunny)"

# Word：在符合文字後插入 block table（自動切開 paragraph）
officecli add doc.docx '/body/p[1]' --type table --after "find:First sentence." --prop rows=2 --prop cols=2
```

### Clone

`officecli add <file> / --from '/slide[1]'` 會連同所有 cross-part relationships 一起複製。

### move、swap、remove

```bash
officecli move <file> <path> [--to <parent>] [--index N] [--after <path>] [--before <path>]
officecli swap <file> <path1> <path2>
officecli remove <file> '/body/p[4]'
```

使用 `--after` 或 `--before` 時可以省略 `--to`；target container 會從 anchor 推導。

### batch — 一個 save cycle 執行多個 operations

**預設 Atomic（v1.0.137+）：**每個 item 都會執行並回報（所以 `N succeeded, M failed` 仍有意義，每個 failure 都會浮出來），但只要任一 item 失敗，整個 batch 就 rollback；disk 上的檔案會和 batch 執行前 byte-identical（standalone 與 resident mode 都已 live 確認）。使用 `--best-effort` 可恢復舊的「成功多少套用多少」行為，適合 lossy `dump→batch` replay：一個不支援的 item 若讓整批丟失，代價可能比 partial result 更高。`--stop-on-error` 只改變停止時機（剩餘 items 會是 `skipped`），不改變已執行內容是否保留；要「第一個 failure 就停，但保留已成功內容」時，和 `--best-effort` 一起使用。`--force` 無關，它只用來 bypass docx protection。Failed item 會帶 machine-readable `code` field（和 `error.code` 使用同一份清單）；rollback 的 batch JSON summary 會帶 `"atomicRolledBack": true`。

`officecli dump <file> [<path>]` 會輸出可 replay 的 batch JSON，供 round-trip 使用：`.docx`（full coverage）、`.pptx`（text/tables/pictures/charts/notes/theme + OLE/3D/video/audio/SmartArt/morph/p15 transitions，透過 raw-set passthrough），以及 `.xlsx`（cells/formulas/styles + tables、conditional formatting、validations、comments、charts、sparklines、pictures、shapes、pivot tables；slicers/chartEx/OLE 透過 verbatim carrier）。Path 預設是 `/`（整份文件）；傳入 subtree path（docx：`/body`、`/body/p[N]`、`/body/tbl[N]`、`/theme`、`/settings`、`/numbering`、`/styles`；xlsx：`/SheetName`、`/sheet[N]`）可限制 dump 範圍。`officecli refresh <file.docx>` 會在 replay 後重新計算 TOC page numbers／PAGE／cross-references（Windows 使用 Word backend；其他平台使用 headless-HTML fallback）。`officecli plugins list` 會把 export 支援擴充到 `.doc`、`.hwpx`、`.pdf`。

```bash
echo '[
  {"command":"set","path":"/Sheet1/A1","props":{"value":"Name","bold":"true"}},
  {"command":"set","path":"/Sheet1/B1","props":{"value":"Score","bold":"true"}}
]' | officecli batch data.xlsx --json

officecli batch data.xlsx --commands '[{"op":"set","path":"/Sheet1/A1","props":{"value":"Done"}}]' --json
officecli batch data.xlsx --input updates.json --best-effort --json   # 某些 items 失敗時仍保留成功項目
```

支援：`add`、`set`、`get`、`query`、`remove`、`move`、`swap`、`view`、`raw`、`raw-set`、`validate`。Fields：`command`（或 `op`）、`path`、`parent`、`type`、`from`、`to`、`index`、`after`、`before`、`props`、`selector`、`mode`、`depth`、`part`、`xpath`、`action`、`xml`。

---

## L3：Raw XML

L2 無法表達需求時才使用。無需 `xmlns` declarations；prefixes 會自動註冊。

```bash
officecli raw <file> <part>                          # view raw XML
officecli raw-set <file> <part> --xpath "..." --action replace --xml '<w:p>...</w:p>'
officecli add-part <file> <parent>                   # create new document part (returns rId)
```

`raw-set` actions：`append`、`prepend`、`insertbefore`、`insertafter`、`replace`、`remove`、`setattr`。可用 parts 執行 `officecli help <format> raw` 查詢。

---

## 常見陷阱

| 陷阱 | 正確作法 |
|---------|-----------------|
| `--name "foo"` | 使用 `--prop name="foo"`；所有 attributes 都要經過 `--prop` |
| zsh/bash 中未加引號的 `[N]` paths | 一律加引號：`'/slide[1]'` 或 `"/slide[1]"`（shell 會對 brackets 做 glob expansion） |
| 用 PPT `shape[1]` 當 content | `shape[1]` 通常是 title placeholder；content shapes 使用 `shape[2]+` |
| `/shape[myname]` | 不支援 name indexing；使用 numeric index 或 `@name=`（只限 PPT） |
| 猜 property names | 執行 `officecli help <format> <element>` 查看 exact names |
| 修改已開啟的檔案 | 先在 PowerPoint/WPS 關閉檔案 |
| shell string 中的 `\n` | `--prop text="..."` 的 newline 使用 `\\n` |
| shell text 中的 `$` | `--prop text="$15M"` 會剝掉 `$15`；使用 single quotes：`--prop text='$15M'`，或用 heredoc batch |

---

## Specialized Skills

`officecli load_skill <name>` 會輸出一份 SKILL.md，必須遵守其中規則。

**Loading rule：**
- 從「When to use」選最具體的 match；沒有符合時，載入 format default（`word`／`pptx`／`excel`）。
- Scenes 已包含 format default 的規則；每個 artifact 只載入 **一個** skill，不要疊加。
- 已載入的規則會跨 turns 保留，不要每次 reply 重載。
- 兩個不同 artifacts → 分別載入兩次。

### Word（.docx）

| Name | 使用時機 |
|------|-------------|
| `word` | Reports、letters、memos、proposals、一般文件 |
| `academic-paper` | Journal／conference／thesis：APA／Chicago／IEEE／MLA citations、equations、SEQ + PAGEREF cross-refs、multi-column journal layout、bibliography。Business reports 或 letters 請 route 到 `word` |

### PowerPoint（.pptx）

| Name | 使用時機 |
|------|-------------|
| `pptx` | 一般 decks：board reviews、sales decks、all-hands、product launches |
| `pitch-deck` | **只限 Fundraising**：seed／Series A-C／SAFE／convertible／strategic raise。Sales／product／board decks 請 route 到 `pptx` |
| `morph-ppt` | Cinematic Morph-animated presentations。Static decks 請 route 到 `pptx` |
| `morph-ppt-3d` | 3D Morph：GLB models、camera moves、depth。只有 2D 的 Morph 請 route 到 `morph-ppt` |

### Excel（.xlsx）

| Name | 使用時機 |
|------|-------------|
| `excel` | 一般 workbooks、formulas、pivots、trackers |
| `financial-model` | Financial models、scenarios、projections。一般 data analysis 請 route 到 `excel` |
| `data-dashboard` | CSV/tabular data → KPI／analytics／executive dashboards，含 charts 與 sparklines。Raw data tracking 請 route 到 `excel` |

例如：fundraising deck task → `officecli load_skill pitch-deck` → 遵守輸出的規則。

---

## Notes

- Paths 是 **1-based**（XPath convention）：`'/body/p[3]'` = 第三個 paragraph。
- `--index` 是 **0-based**（array convention）：`--index 0` = 第一個 position。
- **Excel exception：** `add --type row` 與 `add --type col` 的 `--index N` 是 **1-based**（對應 OOXML RowIndex／column letter index）。`--index 5` 會插入 row 5／column 5。
- 修改後使用 `validate` 和／或 `view issues` 驗證。
- **不確定時**執行 `officecli help <format> <element>`，不要猜。
