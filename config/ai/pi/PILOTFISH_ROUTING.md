# Pi 的 Pilotfish routing

Pi 透過 `pilotfish-routing.ts` 共用 OpenCode harness 的 role routing。
正常 prompt 會自動注入 route directive，由主 session 呼叫
`pilotfish_dispatch`，再以獨立、不可遞迴的 child Pi session 執行 bounded task。
child 結果回到主 session，由主 session 負責整合與最終判斷。

也保留手動 model route：

```text
/pilotfish scout
/pilotfish executor
/pilotfish verifier
```

extension 會讀取目前 project 的
`.opencode/pilotfish/routing.json`，依 candidate 順序尋找 Pi 已註冊且已
完成 authentication 的 model；找不到時依 routing 的 fallback 順序嘗試下一個。
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
可用 `PILOTFISH_ROUTING_PATH=/path/to/routing.json` 指定。
