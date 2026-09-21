import fs from "node:fs"
import path from "node:path"

function append(event: string, tool: string, inputBytes: number, outputBytes = 0): void {
  if (process.env.JEV_COMPACTION_SHADOW === "0") return
  const logPath = process.env.JEV_COMPACTION_SHADOW_LOG ||
    path.join(process.env.HOME || ".", ".local/state/miyago/jev/compaction-shadow.jsonl")
  try {
    fs.mkdirSync(path.dirname(logPath), { recursive: true, mode: 0o700 })
    fs.appendFileSync(logPath, JSON.stringify({
      ts: new Date().toISOString(), event, tool: tool.slice(0, 120),
      input_bytes: inputBytes, output_bytes: outputBytes, mode: "shadow",
      proposed_policy: { keep_first: 4, keep_recent: 8, drop_stale: false },
    }) + "\n", { mode: 0o600 })
    fs.chmodSync(logPath, 0o600)
  } catch {
    // Shadow telemetry must never affect Pi.
  }
}

export default function (pi): void {
  pi.on("tool_execution_end", (event) => {
    append("tool_execution_end", String(event.toolName || ""), 0)
  })
  pi.on("auto_compaction_start", () => {
    append("auto_compaction_start", "", 0)
  })
}
