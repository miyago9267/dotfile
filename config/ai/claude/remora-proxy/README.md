# Remora Proxy (CLIProxyAPI native + aluo)

讓 Claude Code harness 跑在 GPT-5.6 fleet 上的閘道。CLIProxyAPI 以 native binary + launchd
常駐（不用 Docker），上游接 **aluo**（OpenAI-compatible 中轉，轉發官方 `gpt-5.6-sol/terra/luna`）。

## 為什麼是這個組合

- **native 而非 Docker**：省掉 Docker Desktop 的 VM 開銷；重啟是秒級 process，不是重啟 container。
- **aluo 而非逆向 codex**：逆向 codex 訂閱來源 prefill 只有 ~530 tok/s（40K context 冷啟 83 秒），
  aluo 走官方 API，同樣 40K prefill 2.5 秒（~32x），且沒有 codex 的 cooldown / active-turn 邊界問題。
- **remora 調度不受影響**：三層 `role → model` 映射（scout→luna、executor→terra、verifier→sol）原封不動，
  只是這三個 model 名的後端來源換成 aluo。

## 檔案

| 檔 | 用途 |
| --- | --- |
| `config.native.yaml.tmpl` | CLIProxyAPI 設定樣板（key 用 placeholder，實檔含 secret 不進 git） |
| `com.miyago.cliproxyapi.plist.tmpl` | launchd 常駐樣板（路徑 placeholder） |
| `remora.config.toml` | remora 設定（三層 routing + effort + concurrency，無 secret，直接複製） |
| `../../../script/common/install_remora_proxy.sh` | 冪等安裝與設定同步 playbook |

## 用法

```bash
# 互動選單（會列在「工具」分類）
bash setup.sh

# 或直接跑
bash script/common/install_remora_proxy.sh          # 安裝／更新 Remora、Calico、proxy，並同步設定
bash script/common/install_remora_proxy.sh --force   # 另外重新產生 config.native.yaml
```

playbook 會：驗證並安裝對應的 Remora release、與原生 Claude Code 同版本的 Calico binary（獨立放在
`~/.local/bin/calico-claude`）→ 抓 CLIProxyAPI binary → 解析 secret → 產生 config 與 plist → 載入
launchd → 驗證 port 與 `remora doctor --online`。Calico 不會覆蓋原生 `claude`。

`setup.sh --all` 會包含這個項目；互動式執行時可在「工具」選取它。一般的 Claude 設定同步也會覆蓋
`~/.config/remora-cc/config.toml`，因此 pull dotfile 後再次執行 `bash setup.sh` 即可套用受版本控制的
Remora model 與 context 設定。

## Secret 來源（aluo api-key，依序嘗試）

1. `export ALUO_API_KEY=...`
2. `~/.config/opencode/secrets/aluo-api-key`（opencode 已用同一把）
3. sops：`secrets/tokens.enc.yaml` 的 `aluo_api_key`

CLIProxyAPI 的 client auth key 存 macOS Keychain（`remora-proxy-key`），沒有會自動生成並寫回。

## 前置

需要原生 Claude Code、`gh`、`curl`、`shasum`、`tar`。安裝腳本會使用 release SHA-256 與 GitHub
attestation 驗證 Remora 與 Calico artifacts，再進行安裝。

## Pilotfish 對應

不釘版本，一律跟 latest：pilotfish（global agents + CLAUDE.md block）照上游
`install/AGENT-INSTALL.md` 更新到最新 tag；remora 裝最新 release 即可。
`remora.config.toml` 的 role keys 對應 pilotfish 目前的 roster（v1.2.0 起為八個
roles，新增 read-only 的 `plan-verifier` / `security-reviewer`）。remora >= 0.1.10
session 內自帶完整八 role；更舊的六 role config 靠 fallback 相容（`plan-verifier`
← `verifier`、`security-reviewer` ← `security-executor`），config 裡顯式列出是為了
讓 routing / effort 不依賴 fallback 行為。

## 切回逆向 codex（fallback）

codex OAuth cred 保留在 `~/containers/cliproxyapi/auths-codex-fallback/`。要切回：

```bash
mv ~/containers/cliproxyapi/auths-codex-fallback/*.json ~/containers/cliproxyapi/auths/
# 移除 config.native.yaml 的 openai-compatibility 段，然後
launchctl kickstart -k "gui/$(id -u)/com.miyago.cliproxyapi"
```

## 跨平台

目前 playbook 是 darwin（launchd + Keychain）。Linux 對應要換 systemd unit + 另一套 secret 來源，
尚未實作（TODO）。
