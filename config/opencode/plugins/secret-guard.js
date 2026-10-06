// secret guard：bash 工具執行前，把指令交給 config/ai/shared/hooks/secret-guard-adapter.sh
// （它再呼叫 Claude 那份 secret-guard.sh，判斷規則只維護一份），命中就 throw Error 擋下這次呼叫。
// 檔案讀取的邊界在 opencode.json 的 permission.read；這裡只管 bash 指令。
//
// 這層是防合作型 agent 的意外外洩，不是硬邊界：adapter 找不到、執行失敗、逾時、
// 輸出不是預期格式、或讀不到指令字串時一律放行（fail-open）。
//
// 需實測：output.args 裡 bash 指令的鍵名官方文件沒有寫明（文件只示範 read 的 filePath）。
// 這裡依序試 command、cmd、script；都讀不到字串就放行。確認實際鍵名後可收斂。
// 這個目錄下的每個 export 都會被 OpenCode 當成 plugin 載入，所以只 export 一個函式。
import { spawnSync } from "node:child_process";
import { existsSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const SecretGuard = async (input) => {
  const COMMAND_KEYS = ["command", "cmd", "script"];
  const CWD_KEYS = ["workdir", "cwd"];
  const TIMEOUT_MS = 8000;

  const firstString = (args, keys) => {
    if (typeof args !== "object" || args === null) return "";
    for (const key of keys) {
      const value = args[key];
      if (typeof value === "string" && value !== "") return value;
    }
    return "";
  };

  // SECRET_GUARD_ADAPTER 可覆寫（測試用）；否則從這個檔的實際位置找，再退到固定的 dotfile 路徑。
  const adapterPath = () => {
    const override = process.env.SECRET_GUARD_ADAPTER;
    if (override) return override;
    const candidates = [];
    try {
      const here = dirname(realpathSync(fileURLToPath(import.meta.url)));
      candidates.push(resolve(here, "../../ai/shared/hooks/secret-guard-adapter.sh"));
    } catch {
      // 位置解析失敗就只用下面的固定路徑
    }
    candidates.push(resolve(process.env.HOME || homedir(), "dotfile/config/ai/shared/hooks/secret-guard-adapter.sh"));
    return candidates.find((candidate) => existsSync(candidate)) ?? "";
  };

  const directory = typeof input?.directory === "string" && input.directory !== "" ? input.directory : process.cwd();

  return {
    "tool.execute.before": async (hookInput, output) => {
      let reason = "";
      try {
        if (hookInput?.tool !== "bash") return;
        const command = firstString(output?.args, COMMAND_KEYS);
        if (command === "") return;
        const adapter = adapterPath();
        if (adapter === "") return;
        const cwd = firstString(output?.args, CWD_KEYS) || directory;
        const result = spawnSync("bash", [adapter, "--host", "opencode"], {
          input: JSON.stringify({ tool: "bash", command, cwd }),
          encoding: "utf8",
          timeout: TIMEOUT_MS,
          stdio: ["pipe", "pipe", "ignore"],
        });
        if (result.error || result.status !== 0 || !result.stdout) return;
        const verdict = JSON.parse(result.stdout);
        if (verdict?.decision === "deny") {
          reason = typeof verdict.reason === "string" && verdict.reason !== "" ? verdict.reason : "secret-guard: denied";
        }
      } catch {
        return;
      }
      if (reason !== "") throw new Error(reason);
    },
  };
};
