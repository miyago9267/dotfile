import { readFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ModelRef = { provider: string; model: string };
type Route = { candidates?: ModelRef[]; fallback?: string };
type RoutingConfig = { version: number; roles?: Record<string, Route> };

const PROVIDER_ALIASES: Record<string, string> = { openai: "openai-codex" };
const MODEL_ALIASES: Record<string, string> = {
  "deepseek/deepseek-v4-flash": "deepseek/deepseek-flash",
};
async function readJson<T>(path: string): Promise<T> {
  return JSON.parse(await readFile(path, "utf8")) as T;
}

function piRef(ref: ModelRef): ModelRef {
  const requested = `${ref.provider}/${ref.model}`;
  const resolved = MODEL_ALIASES[requested] ?? requested;
  const slash = resolved.indexOf("/");
  return {
    provider: PROVIDER_ALIASES[resolved.slice(0, slash)] ?? resolved.slice(0, slash),
    model: resolved.slice(slash + 1),
  };
}

function classify(prompt: string): string | undefined {
  const text = prompt.toLowerCase();
  if (!/(code|file|repo|project|implement|fix|change|add|update|refactor|test|review|security|find|search|inspect|debug|程式|程式碼|檔案|儲存庫|專案|實作|修復|修改|新增|更新|重構|測試|審查|安全|尋找|搜尋|檢查|除錯)/.test(text)) return undefined;
  if (/(security|secret|credential|permission|auth|vulnerability|attack|安全|密鑰|憑證|權限|漏洞|攻擊)/.test(text)) return "security-reviewer";
  if (/(review|verify|verification|check whether|is this correct|test the change|審查|驗證|確認|檢查是否|是否正確)/.test(text)) return "verifier";
  if (/(find|search|where|which file|explain|inspect|locate|list|尋找|搜尋|哪個檔案|說明|檢視|定位|列出)/.test(text) && !/(implement|fix|change|add|update|實作|修復|修改|新增|更新)/.test(text)) return "scout";
  if (/(mechanical|rename all|replace all|repetitive|bulk|機械|全部重新命名|全部替換|重複|批次)/.test(text)) return "mech-executor";
  return "executor";
}

async function candidatesFor(role: string, cwd: string): Promise<ModelRef[]> {
  const path = process.env.PILOTFISH_ROUTING_PATH || join(resolve(cwd), ".opencode", "pilotfish", "pi-routing.json");
  const routing = await readJson<RoutingConfig>(path);
  const candidates = routing.roles?.[role]?.candidates;
  if (!candidates?.length) throw new Error(`Pilotfish role has no route: ${role}`);
  return candidates;
}

async function runChild(model: string, task: string, cwd: string): Promise<string> {
  const child = spawn("pi", ["--print", "--no-session", "--no-extensions", "--model", model], {
    cwd,
    env: { ...process.env, PILOTFISH_CHILD: "1" },
    stdio: ["pipe", "pipe", "pipe"],
  });
  const stdout: Buffer[] = [];
  const stderr: Buffer[] = [];
  child.stdout.on("data", (chunk: Buffer) => stdout.push(chunk));
  child.stderr.on("data", (chunk: Buffer) => stderr.push(chunk));
  child.stdin.write(task);
  child.stdin.end();

  const result = await new Promise<{ code: number | null }>((resolveResult, reject) => {
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error("child Pi timed out after 5 minutes"));
    }, 300_000);
    child.once("error", reject);
    child.once("close", (code) => {
      clearTimeout(timer);
      resolveResult({ code });
    });
  });
  const output = Buffer.concat(stdout).toString("utf8").trim();
  if (result.code !== 0) {
    const error = Buffer.concat(stderr).toString("utf8").trim();
    throw new Error(`${output || error || `child Pi exited with ${result.code}`}`);
  }
  return output.slice(-20_000);
}

export default function (pi: ExtensionAPI) {
  // The child process is deliberately non-orchestrating to prevent recursion.
  if (process.env.PILOTFISH_CHILD === "1") return;

  pi.registerTool({
    name: "pilotfish_dispatch",
    label: "Pilotfish dispatch",
    description: "Dispatch a bounded task to an isolated Pi child session using the Pilotfish role model route.",
    parameters: Type.Object({
      role: Type.String({ description: "Pilotfish role: scout, executor, mech-executor, verifier, reviewer, plan-verifier, security-reviewer, or security-executor" }),
      task: Type.String({ description: "Complete bounded task for the child session" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const candidates = await candidatesFor(params.role, ctx.cwd);
      const attempts: string[] = [];
      for (const candidate of candidates) {
        const selected = piRef(candidate);
        if (!ctx.modelRegistry.find(selected.provider, selected.model)) {
          attempts.push(`${candidate.provider}/${candidate.model}: unavailable in Pi`);
          continue;
        }
        try {
          const output = await runChild(`${selected.provider}/${selected.model}`, params.task, ctx.cwd);
          return { content: [{ type: "text", text: `Pilotfish ${params.role} result (${candidate.provider}/${candidate.model}):\n\n${output}` }], details: { role: params.role, model: candidate } };
        } catch (error) {
          attempts.push(`${candidate.provider}/${candidate.model}: ${error instanceof Error ? error.message : String(error)}`);
        }
      }
      throw new Error(attempts.join("; "));
    },
  });

  pi.on("before_agent_start", async (event) => {
    const role = classify(event.prompt);
    if (!role) return;
    return {
      message: {
        customType: "pilotfish-auto-route",
        content: `Pilotfish automatic route selected: ${role}. Before doing the task yourself, call pilotfish_dispatch with role=${role} and a bounded task description. Use the child result as evidence; retain ownership of integration, approval, and final judgment in this session.`,
        display: false,
      },
    };
  });

  pi.registerCommand("pilotfish", {
    description: "Select a model through the project Pilotfish role route",
    handler: async (args, ctx) => {
      const role = args.trim() || "executor";
      try {
        const candidates = await candidatesFor(role, ctx.cwd);
        for (const candidate of candidates) {
          const selected = piRef(candidate);
          const model = ctx.modelRegistry.find(selected.provider, selected.model);
          if (model && await pi.setModel(model)) {
            ctx.ui.notify(`Pilotfish ${role} → ${candidate.provider}/${candidate.model}`, "info");
            return;
          }
        }
        throw new Error("No usable authenticated candidate");
      } catch (error) {
        ctx.ui.notify(`Pilotfish route failed: ${error instanceof Error ? error.message : String(error)}`, "error");
      }
    },
  });
}
