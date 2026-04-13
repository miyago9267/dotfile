import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { unlinkSync, existsSync, mkdirSync, writeFileSync, readFileSync } from "fs";

const SOCK_DIR = `${process.env.HOME}/.cache/ask-tty`;
const SOCK_PATH = `${SOCK_DIR}/bridge.sock`;
const PID_PATH = `${SOCK_DIR}/bridge.pid`;

// --- State machine ---
// idle → waiting (exec_start) → running (hook sends input) → done (command finishes) → idle (result polled)

type State =
  | { status: "idle" }
  | { status: "waiting"; prompt: string; sensitive: boolean; resolve: (input: string) => void }
  | { status: "running"; command: string }
  | { status: "done"; stdout: string; stderr: string; exitCode: number }
  | { status: "error"; message: string };

let state: State = { status: "idle" };

function ensureDir() {
  if (!existsSync(SOCK_DIR)) mkdirSync(SOCK_DIR, { recursive: true });
}

function shellEscape(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

function ensureSudoS(command: string): string {
  if (/\bsudo\s/.test(command) && !/\bsudo\s+-\S*S/.test(command)) {
    return command.replace(/\bsudo\s/, "sudo -S ");
  }
  return command;
}

async function runCommand(command: string, input?: string) {
  let finalCommand = command;
  if (input !== undefined) {
    finalCommand = `printf '%s\\n' ${shellEscape(input)} | ${ensureSudoS(command)}`;
  }

  const proc = Bun.spawn(["bash", "-c", finalCommand], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, DEBIAN_FRONTEND: "noninteractive" },
  });

  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  const cleanStderr = stderr.replace(/^\[sudo\] password for \S+:\s*/gm, "").trim();

  state = { status: "done", stdout: stdout.trim(), stderr: cleanStderr, exitCode };
}

// --- Unix socket HTTP server (condition variable) ---

ensureDir();

if (existsSync(PID_PATH)) {
  const existing = parseInt(readFileSync(PID_PATH, "utf-8").trim(), 10);
  if (existing !== process.pid) {
    try {
      process.kill(existing, 0);
      console.error(`pty-bridge: another instance (PID ${existing}) is running, exiting`);
      process.exit(0);
    } catch {}
  }
}

try { unlinkSync(SOCK_PATH); } catch {}
writeFileSync(PID_PATH, String(process.pid));

function removeSock() {
  try { unlinkSync(SOCK_PATH); } catch {}
  try { unlinkSync(PID_PATH); } catch {}
}
process.on("exit", removeSock);
process.on("SIGINT", () => { removeSock(); process.exit(0); });
process.on("SIGTERM", () => { removeSock(); process.exit(0); });

Bun.serve({
  unix: SOCK_PATH,
  fetch(req) {
    const url = new URL(req.url);

    if (req.method === "GET" && url.pathname === "/state") {
      if (state.status === "waiting") {
        return Response.json({ status: "waiting", prompt: state.prompt, sensitive: state.sensitive });
      }
      return Response.json({ status: state.status });
    }

    if (req.method === "POST" && url.pathname === "/input") {
      if (state.status !== "waiting") {
        return Response.json({ error: "not waiting" }, { status: 409 });
      }
      return req.text().then((body) => {
        (state as Extract<State, { status: "waiting" }>).resolve(body.trim());
        return Response.json({ ok: true });
      });
    }

    return new Response("not found", { status: 404 });
  },
});

// --- MCP Server ---

const server = new McpServer({ name: "pty-bridge", version: "2.0.0" });

// Non-blocking: start command, return immediately
server.tool(
  "exec",
  "Start a command. If needs_stdin=true, sets state to 'waiting' -- user types input in the prompt box, then call 'result' to get output. If needs_stdin=false, runs directly -- call 'result' to get output.",
  {
    command: z.string().describe("The bash command to execute"),
    needs_stdin: z.boolean().default(false).describe("Whether the command needs user input (sudo, ssh, etc.)"),
    stdin_prompt: z.string().default("Input required").describe("What input is needed (shown to user)"),
    sensitive: z.boolean().default(false).describe("Whether the input is a password/secret"),
    timeout: z.number().default(120).describe("Timeout in seconds for user input"),
  },
  async ({ command, needs_stdin, stdin_prompt, sensitive, timeout }) => {
    if (state.status !== "idle" && state.status !== "done" && state.status !== "error") {
      return { content: [{ type: "text", text: `Busy: state is '${state.status}'. Call 'result' first.` }], isError: true };
    }

    if (!needs_stdin) {
      // No stdin needed: fire and forget, result will be available via 'result' tool
      state = { status: "running", command };
      runCommand(command).catch((e) => { state = { status: "error", message: (e as Error).message }; });
      return { content: [{ type: "text", text: "Started. Call 'result' to get output." }] };
    }

    // Needs stdin: set state to waiting, return IMMEDIATELY (non-blocking)
    const timer = setTimeout(() => {
      if (state.status === "waiting") {
        state = { status: "error", message: `Timed out waiting for input (${timeout}s)` };
      }
    }, timeout * 1000);

    state = {
      status: "waiting",
      prompt: stdin_prompt,
      sensitive,
      resolve: (input: string) => {
        clearTimeout(timer);
        state = { status: "running", command };
        runCommand(command, input).catch((e) => { state = { status: "error", message: (e as Error).message }; });
      },
    };

    return { content: [{ type: "text", text: `Waiting for input: ${stdin_prompt}` }] };
  },
);

// Poll for result
server.tool(
  "result",
  "Get the result of the last exec command. Returns output when done, or current status if still running.",
  {},
  async () => {
    if (state.status === "done") {
      const { stdout, stderr, exitCode } = state;
      state = { status: "idle" };

      const parts: string[] = [];
      if (stdout) parts.push(stdout);
      if (stderr) parts.push(`[stderr] ${stderr}`);
      parts.push(`[exit ${exitCode}]`);

      return { content: [{ type: "text", text: parts.join("\n") }], isError: exitCode !== 0 };
    }

    if (state.status === "error") {
      const msg = state.message;
      state = { status: "idle" };
      return { content: [{ type: "text", text: `Error: ${msg}` }], isError: true };
    }

    return { content: [{ type: "text", text: `Status: ${state.status}. Not done yet.` }] };
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
