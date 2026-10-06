// plugins/secret-guard.js 的單元測試（bun test）。放在 plugins/ 之外，OpenCode 才不會把它當 plugin 載入。
// 指令只以字串交給 plugin 的 hook，由 adapter 與 secret-guard.sh 判斷，不會被執行；不啟動 OpenCode。
import { afterEach, beforeAll, afterAll, describe, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import * as pluginModule from "../plugins/secret-guard.js";

const { SecretGuard } = pluginModule;
const HOME = process.env.HOME;
let tmp;

beforeAll(() => {
  tmp = mkdtempSync(join(tmpdir(), "secret-guard-plugin-"));
});
afterAll(() => {
  rmSync(tmp, { recursive: true, force: true });
});
afterEach(() => {
  delete process.env.SECRET_GUARD_ADAPTER;
});

function stub(name, body) {
  const path = join(tmp, name);
  writeFileSync(path, `#!/bin/bash\n${body}\n`);
  chmodSync(path, 0o755);
  return path;
}

async function before(tool, args, directory = "/tmp/work") {
  const hooks = await SecretGuard({ directory });
  return hooks["tool.execute.before"]({ tool, sessionID: "ses_x", callID: "call_x" }, { args });
}

describe("module shape", () => {
  test("只 export 一個 plugin 函式", () => {
    expect(Object.keys(pluginModule)).toEqual(["SecretGuard"]);
    expect(typeof SecretGuard).toBe("function");
  });
  test("回傳的 hooks 只有 tool.execute.before", async () => {
    expect(Object.keys(await SecretGuard({ directory: "/tmp" }))).toEqual(["tool.execute.before"]);
  });
});

describe("經真正的 adapter 與 secret-guard.sh", () => {
  const denied = [
    ["kubectl config view --raw", "kubectl config view"],
    ["gcloud auth print-access-token", "gcloud auth"],
    ["security find-generic-password -s x -w", "security find-generic-password"],
    ["cd /tmp && sec show", "sec show"],
    ["agent-secret2 edit", "agent-secret2 edit"],
    ["sops -d ~/dotfile/secrets/agent.enc.yaml", "sops"],
  ];
  for (const [command, fragment] of denied) {
    test(`擋下：${command}`, async () => {
      const call = before("bash", { command });
      await expect(call).rejects.toThrow(/^secret-guard: /);
      await expect(before("bash", { command })).rejects.toThrow(fragment);
    });
  }

  const allowed = [
    "ls -la",
    "kubectl config view",
    "agent-secret2 run gitlab-token -- /opt/homebrew/bin/glab mr list",
    'echo "sec show; gcloud auth print-access-token"',
    "sops -d other.enc.yaml",
  ];
  for (const command of allowed) {
    test(`放行：${command}`, async () => {
      await expect(before("bash", { command })).resolves.toBeUndefined();
    });
  }

  test("cmd、script 鍵名也讀得到", async () => {
    await expect(before("bash", { cmd: "sec show" })).rejects.toThrow(/secret-guard/);
    await expect(before("bash", { script: "sec show" })).rejects.toThrow(/secret-guard/);
  });

  test("相對路徑以 plugin 的 directory 解析", async () => {
    const command = "sops -d secrets/agent.enc.yaml";
    await expect(before("bash", { command }, `${HOME}/dotfile`)).rejects.toThrow(/secret-guard/);
    await expect(before("bash", { command }, "/tmp/work")).resolves.toBeUndefined();
  });

  test("args.workdir 優先於 plugin 的 directory", async () => {
    const command = "sops -d secrets/agent.enc.yaml";
    await expect(before("bash", { command, workdir: `${HOME}/dotfile` }, "/tmp/work")).rejects.toThrow(/secret-guard/);
  });
});

describe("不經 guard 就放行", () => {
  test("bash 以外的工具（adapter 不會被呼叫）", async () => {
    const marker = join(tmp, "called-other-tool");
    process.env.SECRET_GUARD_ADAPTER = stub("mark-other.sh", `cat >/dev/null; touch "${marker}"; echo '{"decision":"deny","reason":"secret-guard: x"}'`);
    await expect(before("read", { filePath: "/tmp/x", command: "sec show" })).resolves.toBeUndefined();
    await expect(before("task", { command: "sec show" })).resolves.toBeUndefined();
    expect(() => readFileSync(marker)).toThrow();
  });

  test("讀不到指令字串", async () => {
    for (const args of [undefined, null, {}, { command: "" }, { command: 42 }, { command: ["sec", "show"] }, { other: "sec show" }, "sec show"]) {
      await expect(before("bash", args)).resolves.toBeUndefined();
    }
  });

  test("hook 參數缺漏", async () => {
    const hooks = await SecretGuard(undefined);
    await expect(hooks["tool.execute.before"](undefined, undefined)).resolves.toBeUndefined();
    await expect(hooks["tool.execute.before"]({ tool: "bash" }, undefined)).resolves.toBeUndefined();
  });
});

describe("adapter 的回傳轉接", () => {
  test("傳給 adapter 的是 --host opencode 與 {tool, command, cwd}", async () => {
    const seen = join(tmp, "seen.json");
    const argv = join(tmp, "argv.txt");
    process.env.SECRET_GUARD_ADAPTER = stub("record.sh", `printf '%s ' "$@" > "${argv}"; cat > "${seen}"`);
    await before("bash", { command: "ls -la" }, "/tmp/somewhere");
    expect(JSON.parse(readFileSync(seen, "utf8"))).toEqual({ tool: "bash", command: "ls -la", cwd: "/tmp/somewhere" });
    expect(readFileSync(argv, "utf8").trim()).toBe("--host opencode");
  });

  test("deny 的 reason 成為 Error 訊息", async () => {
    process.env.SECRET_GUARD_ADAPTER = stub("deny.sh", `cat >/dev/null; echo '{"decision":"deny","reason":"secret-guard: 測試原因"}'`);
    await expect(before("bash", { command: "ls" })).rejects.toThrow("secret-guard: 測試原因");
  });

  test("deny 沒帶 reason 時用預設訊息", async () => {
    process.env.SECRET_GUARD_ADAPTER = stub("deny-bare.sh", `cat >/dev/null; echo '{"decision":"deny"}'`);
    await expect(before("bash", { command: "ls" })).rejects.toThrow("secret-guard: denied");
  });

  // teeth：把 adapter 換成永遠放行的假貨，原本會被擋的指令就放行，證明 deny 來自 guard
  test("adapter 無輸出就放行", async () => {
    process.env.SECRET_GUARD_ADAPTER = stub("allow.sh", "cat >/dev/null; exit 0");
    await expect(before("bash", { command: "sec show" })).resolves.toBeUndefined();
  });

  test("其他 decision、非 JSON、非零 exit、adapter 不存在：fail-open", async () => {
    const cases = [
      stub("ask.sh", `cat >/dev/null; echo '{"decision":"ask","reason":"x"}'`),
      stub("garbage.sh", "cat >/dev/null; echo not-json"),
      stub("fail.sh", `cat >/dev/null; echo '{"decision":"deny","reason":"x"}'; exit 3`),
      join(tmp, "does-not-exist.sh"),
    ];
    for (const adapter of cases) {
      process.env.SECRET_GUARD_ADAPTER = adapter;
      await expect(before("bash", { command: "sec show" })).resolves.toBeUndefined();
    }
  });
});
