# officecli — 指令參考（L1 / L2 / L3）

## L1：建立、讀取與檢查

```bash
officecli create <file>               # 建立空白 .docx/.xlsx/.pptx（類型取自副檔名）
officecli view <file> <mode>          # outline | stats | issues | text | annotated | html
officecli get <file> <path> --depth N # 取得 node 與其 children [--json]
officecli query <file> <selector>     # CSS-like query
officecli validate <file>             # 依 OpenXML schema 驗證
```

### view 模式

| 模式 | 說明 | 常用 flags |
|------|-------------|-------------|
| `outline` | 文件結構 | |
| `stats` | 統計資料（頁數、字數、shapes） | |
| `issues` | 格式、內容與結構問題 | `--type format\|content\|structure`、`--limit N` |
| `text` | 純文字擷取 | `--start N --end N`、`--max-lines N` |
| `annotated` | 附格式標註的文字 | |
| `html` | 靜態 HTML snapshot；與 `watch` 使用相同 renderer，不需要 server | `--browser`、`--page N`（docx）、`--start N --end N`（pptx） |
| `screenshot` / `svg` / `pdf` / `forms` | 透過 headless browser 產生 PNG／pptx slide 的 SVG／exporter plugin 產生 PDF／format-handler plugin 產生 form-fields JSON | `-o`、`--screenshot-width/-height`、pptx `--grid N` |

一次性 snapshot（CI artifacts、封存、diff）使用 `view html`；需要 live refresh 或在 browser 點選時使用 `watch`。

### get

可用 element localName 指定任何 XML path。用 `--depth N` 展開 children；需要結構化輸出時加 `--json`。預設文字輸出方便 grep：`path (type) "text" key=val key=val ...`

```bash
officecli get report.docx '/body/p[3]' --depth 2 --json
officecli get slides.pptx '/slide[1]' --depth 1          # 列出 slide 1 的所有 shapes
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

支援 CSS-like selector：`[attr=value]`、`[attr!=value]`、`[attr~=text]`、`[attr>=value]`、`[attr<=value]`、`:contains("text")`、`:empty`、`:has(formula)`、`:no-alt`。`query`／`set`／`remove` 都支援 Boolean `and`／`or`：`cell[value>5000 or value<100]`、`cell[(type=Number or type=Date) and value>0]`。Excel 可用欄名查詢列：`Sheet1!row[Salary>5000]`。`set` 接受 selector 與 Excel-native path，行為和 `get`／`query` 一致。`set`／`remove` 拒絕沒有 scope 的 bare selector。

```bash
officecli query report.docx 'paragraph[style=Normal] > run[font!=Arial]'
officecli query slides.pptx 'shape[fill=FF0000]'
```

---

## Watch 與互動選取

Live HTML preview 會在每次檔案變更時自動 refresh。可以在 browser click、shift-click 或 box-drag 選取 shapes，再由 CLI 讀取目前 browser selection 並套用操作。

```bash
officecli watch <file> [--port N]      # 啟動 preview server（預設 port 26315）
officecli unwatch <file>               # 停止
officecli goto <file> <path>           # 將 watching browser(s) 捲到 element（docx: p / table / tr / tc）
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
- **支援範圍：** `.pptx` 的 shapes/pictures/tables/charts/connectors/groups；`.docx` 的 top-level paragraphs 與 tables。Inherited layout/master decorations 和 Word nested elements（table cells、run-level）無法尋址。**`.xlsx` 不會產生 `data-path`**，所以 xlsx 的 `mark`／`selection` 永遠解析成 `stale=true`（v2 candidate）。

### Marks — 等待 review 的編輯提案

變更需要在人為套用到檔案前 review 時使用 `mark`。Marks 只存在 watch process；另一個 `set` pipeline 會套用已接受的 marks。一次性變更直接使用 `set`；要建立永久檔案註記則使用 `add --type comment`（Word native）。

```bash
officecli mark <file> <path> [--prop find=... color=... note=... tofix=... regex=true] [--json]
officecli unmark <file> [--path <p> | --all] [--json]
officecli get-marks <file> [--json]
```

Props：`find`（literal；`regex=true` 時為 regex；raw form `find='r"[abc]"'`）、`color`（hex／`rgb(...)`／22 個 named whitelist）、`note`、`tofix`（驅動 apply pipeline）。**Path** 必須使用 watch HTML 產生的 `data-path` 格式；完整 pipeline 見 subskills。

---

## L2：DOM 操作

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
# 格式化符合的文字（自動切分 runs）
officecli set doc.docx '/body/p[1]' --find weather --prop bold=true --prop color=red

# Regex matching（`regex=` 仍是 prop flag）
officecli set doc.docx '/body/p[1]' --find '\d+%' --prop regex=true --prop color=red

# 取代文字（使用 `/` 表示整份文件範圍）
officecli set doc.docx / --find draft --replace final

# docx：tracked Find&Replace
officecli set doc.docx / --find draft --replace final --prop revision.author=Alice

# PPT — 語法相同，paths 不同
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

| Format | 類型 |
|--------|-------|
| **pptx** | slide (incl. hidden), shape (font.latin/ea/cs, direction=rtl, underline.color, highlight=COLOR (Add/Set/Get/HTML preview), effective.X+effective.X.src; arrow alias for rightArrow; slideMaster/slideLayout typed add/set/remove), picture (SVG, brightness/contrast/glow/shadow, rotation, link, tooltip), chart (direction=rtl, pieOfPie, barOfPie, axisLine/gridline per-attr setters, animation+chartBuild=byCategory|bySeries, line dropLines/hiLowLines/upDownBars, anchor=x,y,w,h shorthand), table (cell direction=rtl, fill/background, built-in PowerPoint style catalogue, /col[C] get + swap/copyFrom, row/col Move/CopyFrom), row (tr), connector (from/to accept @name=, startshape/endshape SetByPath), group (link, tooltip, deep walk by get/query/add/remove), video/audio (loop, autoStart alias), equation, notes (direction=rtl, lang), comment (legacy + modern p188 threaded round-trip), animation (15 emphasis + 16 exit presets, multi-effect chains, motion-path presets, repeat/restart/autoReverse, chart animations), transition (12 p15 presets + morph/p14), paragraph (para), run, zoom, ole (preview=, full dump round-trip via add-part+raw-set), placeholder (phType=...), model3d (rotation=ax,ay,az; full dump round-trip), smartart (dump round-trip via add-part). |
| **docx** | paragraph (direction/font.latin/ea/cs, bold.cs/italic.cs/size.cs, lang.latin/ea/cs, wordWrap, framePr.\*, tabs shorthand), run (lang slots, direction, underline.color, position half-pts, **revision.type=ins\|del\|format\|moveFrom\|moveTo + revision.action=accept\|reject** with .author/.date — `/revision[@author=X]` selector for filtered accept/reject), table (direction=rtl, hMerge, **virtual column ops**: add/remove/move/copyfrom on /body/tbl[N]/col), row (tr), cell (td), image, header/footer (direction), section (pageNumFmt full enum, direction=rtl, rtlGutter, pgBorders=box), bookmark, comment, footnote, endnote, formfield, sdt, chart, equation, field (28 types), hyperlink, style (direction, indents, pbdr, lineSpacing on Add/Set), toc, watermark, break, ole, **num/abstractNum/lvl**, **tab**, **textbox/shape** (full Add+Get; geometry, fill, line, wrap, alt, anchor, **rotation, verticalText (eaVert/vert/vert270/wordArt\*), gradient, shadow, opacity**), embedded **OLE round-trip on dump→batch**. docDefaults.rtl, autoHyphenation, `get /` exposes locale + /comments /footnotes /endnotes. `create --minimal` for raw OOXML scaffolding. |
| **xlsx** | sheet (visible/hidden/veryHidden, print margins, printTitleRows/Cols, rightToLeft sheetView, cascade-aware rename), row (c{N}= cell-content shorthand; add accepts --from /Sheet/col[L]; formula-ref rewrite on insert), col (formula-ref rewrite, named-range follow on move), cell (type=richtext+runs, merge=range/sweep, direction=rtl, phonetic; **--shift left\|up on remove, shift=right\|down on add** — Excel UI dialog parity; formula auto-detect; OFFSET/INDIRECT in calc), chart (per-axis RTL/title, anchor=x,y,w,h, pareto), image (SVG), comment (direction=rtl), table (listobject), namedrange (definedname, volatile, `[@name=X]`; formula-body inlined at parse), pivottable (cache CoW + cross-pivot sharing, labelFilter, topN, fillDownLabels, calculatedField), sparkline, validation, autofilter, shape, textbox, CF (databar/colorscale/iconset/formulacf/cellIs/topN/aboveAverage), ole, csv. Query supports `merge`/`mergedrange`. Workbook: password. Shape selector enumerates leaves inside grpSp. |

### Pivot tables（xlsx）

```bash
officecli add data.xlsx /Sheet1 --type pivottable \
  --prop source="Sheet1!A1:E100" --prop rows=Region,Category \
  --prop cols=Year --prop values="Sales:sum,Qty:count" \
  --prop grandTotals=rows --prop subtotals=off --prop sort=asc
```

主要 properties：`rows`、`cols`、`values`（Field:func[:showDataAs]）、`filters`、`source`、`position`、`layout`（compact/outline/tabular）、`repeatLabels`、`blankRows`、`aggregate`、`showDataAs`（percent_of_total/row/col、running_total）、`grandTotals`、`subtotals`、`sort`。Aggregators：sum、count、average、max、min、product、stdDev、stdDevp、var、varp、countNums。Date columns 會自動分組。完整 schema 執行 `officecli help xlsx pivottable`。

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

### Clone（複製）

`officecli add <file> / --from '/slide[1]'` 會連同所有 cross-part relationships 一起複製。

### move、swap、remove

```bash
officecli move <file> <path> [--to <parent>] [--index N] [--after <path>] [--before <path>]
officecli swap <file> <path1> <path2>
officecli remove <file> '/body/p[4]'
```

使用 `--after` 或 `--before` 時可以省略 `--to`；target container 會從 anchor 自動推斷。

### batch — 一次 save cycle 執行多個操作

預設遇到錯誤仍會繼續（任一項失敗時回傳 exit 1）。使用 `--stop-on-error` 可在第一個錯誤時中止。`--force` 是繞過 docx protection 的選項。

`officecli dump <file> [<path>]` 會輸出可 replay 的 batch JSON，用於 round-trip：`.docx`（完整支援）與 `.pptx`（text/tables/pictures/charts/notes/theme，加上透過 raw-set passthrough 的 OLE/3D/video/audio/SmartArt/morph/p15 transitions）。Path 預設為 `/`（整份文件）；傳入 subtree path（`/body`、`/body/p[N]`、`/body/tbl[N]`、`/theme`、`/settings`、`/numbering`、`/styles`）可限定 dump 範圍。replay 後執行 `officecli refresh <file.docx>` 重新計算 TOC page numbers／PAGE／cross-references（Windows 使用 Word backend；其他環境使用 headless-HTML fallback）。`officecli plugins list` 可擴充 `.doc`、`.hwpx` 與 `.pdf` export 支援。

```bash
echo '[
  {"command":"set","path":"/Sheet1/A1","props":{"value":"Name","bold":"true"}},
  {"command":"set","path":"/Sheet1/B1","props":{"value":"Score","bold":"true"}}
]' | officecli batch data.xlsx --json

officecli batch data.xlsx --commands '[{"op":"set","path":"/Sheet1/A1","props":{"value":"Done"}}]' --json
officecli batch data.xlsx --input updates.json --force --json
```

支援：`add`、`set`、`get`、`query`、`remove`、`move`、`swap`、`view`、`raw`、`raw-set`、`validate`。Fields：`command`（或 `op`）、`path`、`parent`、`type`、`from`、`to`、`index`、`after`、`before`、`props`、`selector`、`mode`、`depth`、`part`、`xpath`、`action`、`xml`。

---

## L3：Raw XML

L2 無法表達需求時使用。不要手動加入 xmlns declarations；prefixes 會自動註冊。

```bash
officecli raw <file> <part>                          # 查看 raw XML
officecli raw-set <file> <part> --xpath "..." --action replace --xml '<w:p>...</w:p>'
officecli add-part <file> <parent>                   # 建立新的 document part（回傳 rId）
```

`raw-set` actions：`append`、`prepend`、`insertbefore`、`insertafter`、`replace`、`remove`、`setattr`。執行 `officecli help <format> raw` 查詢可用 parts。

---

## 常見陷阱

| 陷阱 | 正確做法 |
|---------|-----------------|
| `--name "foo"` | 使用 `--prop name="foo"`；所有 attributes 都要透過 `--prop` 傳入 |
| zsh/bash 中未加引號的 `[N]` path | 一律加引號：`'/slide[1]'` 或 `"/slide[1]"`（shell 會對 brackets 做 glob 展開） |
| 用 PPT `shape[1]` 取內容 | `shape[1]` 通常是 title placeholder；內容 shape 使用 `shape[2]+` |
| `/shape[myname]` | 不支援以名稱索引；使用 numeric index 或 `@name=`（僅 PPT） |
| 猜 property 名稱 | 執行 `officecli help <format> <element>` 查看 exact names |
| 修改已開啟的檔案 | 先在 PowerPoint/WPS 關閉檔案 |
| shell string 中的 `\n` | 在 `--prop text="..."` 中使用 `\\n` 表示換行 |
| shell text 中的 `$` | `--prop text="$15M"` 會剝掉 `$15`；使用單引號 `--prop text='$15M'`，或使用 heredoc batch |

---
