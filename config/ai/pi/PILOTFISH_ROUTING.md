# Pi 的 Pilotfish routing

Pi 透過 `pilotfish-routing.ts` 讀取 Pi 專用的 role routing；OpenCode harness
仍使用自己的 `routing.json`，兩者不共用 model binding。
正常 prompt 會自動注入 route directive，由主 session 呼叫
`pilotfish_dispatch`，再以獨立、不可遞迴的 child Pi session 執行 bounded task。
child 結果回到主 session，由主 session 負責整合與最終判斷。

也保留手動 model route：

```text
/pilotfish scout
/pilotfish executor
/pilotfish verifier
/pilotfish plan-verifier
/pilotfish security-reviewer
/pilotfish security-executor
```

目前分配：

| Role | 優先模型 | 後備模型 |
| --- | --- | --- |
| scout、mech-executor | DeepSeek V4 Flash | 無 |
| executor | GPT-6 Luna | Grok 4.6 |
| reviewer | Grok 4.6 | 無 |
| plan-verifier | Claude Opus 5.5 | GPT-6 Sol |
| verifier | Claude Opus 5.5 | GPT-6 Sol、Grok 4.6 |
| security-reviewer | GPT-6 Astra | 無；失敗即停止 |
| security-executor | GPT-6 Sol | GPT-6 Luna |

Opus 5.5 用於獨立 plan challenge 與一般驗證；Astra 留給安全證據審查。
圖片中的 Elo／成本只作為分工參考，不代表各類任務的實測結論。
現有 session 的模型不會因 routing 檔變更而自動切換。

extension 會讀取目前 project 的
`.opencode/pilotfish/pi-routing.json`，依 candidate 順序尋找 Pi 已註冊的
model；未註冊或呼叫失敗時依序嘗試下一個。registry 可見不等於已通過
authentication 或 live request；安全審查沒有後備候選。
它不會把主 session 在不同 role 間反覆切換，也不會改寫 OpenCode 或 Pi credentials。

Pi 與 OpenCode 的 provider ID 不完全相同，目前 `openai` 會映射到 Pi 的
`openai-codex`。其他 provider 使用相同 ID。Pilotfish 本身是 routing／validation
layer，不是 model gateway；因此 Pi 必須先能在 `/model` 或 `pi --list-models`
看到對應 model。

安裝：

```sh
bash script/common/setup_pi.sh
```

之後重新啟動 Pi，或執行 `/reload`。如果 project 不在 routing 檔案預設位置，
可用 `PILOTFISH_ROUTING_PATH=/path/to/pi-routing.json` 指定。
