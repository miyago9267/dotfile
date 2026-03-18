# Utils -- 短指令工具集

加入 PATH 後可直接呼叫（透過 `.zshrc.d/utils.zsh` 自動載入）。

| 指令 | 說明 | 用法 |
|------|------|------|
| `gq` | git add + commit + push 一步到位 | `gq "commit message"` |
| `hs` | 快速 HTTP server | `hs [port]`（預設 8000） |
| `jp` | JSON 格式化 | `jp '{"a":1}'` 或 `curl ... \| jp` |
| `pf` | 查找佔用 port 的 process | `pf 3000` |
| `qb` | 快速備份（加時間戳） | `qb myfile.conf` |
| `qn` | 快速筆記 | `qn add "todo"`、`qn list`、`qn search keyword` |
| `si` | 系統資訊（OS, CPU, RAM, Disk, Network） | `si` |
| `extract` | 智能解壓縮（tar/zip/rar/7z/bz2...） | `extract archive.tar.gz` |
| `runcpp.sh` | C++ 編譯執行（支援 GDB, 最佳化旗標） | `runcpp.sh main.cpp` |
| `cfupdate.py` | CloudFlare DNS 動態更新 | 需設定 API token |
| `init-project` | 專案初始化（Python/Node/Go） | `init-project` |
