"""pilotfish-dispatch-guard.py 與 route 寫 turn 檔的測試。HOME 指到 temp dir，不連網。"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

GUARD = Path(__file__).resolve().parents[3] / "claude/hooks/pilotfish-dispatch-guard.py"
SID, PID = "sess-1", "prompt-1"


class GuardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.state = self.home / ".local/state/miyago/jev"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def call(self, payload=None, raw=None, **env_extra) -> str:
        env = {"PATH": os.environ.get("PATH", ""), "HOME": str(self.home), "TMPDIR": "/var/folders/x/T/"}
        env.update(env_extra)
        done = subprocess.run(
            [sys.executable, str(GUARD)],
            input=raw if raw is not None else json.dumps(payload).encode(),
            capture_output=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(done.returncode, 0, done.stderr.decode())
        return done.stdout.decode()

    def prompt(self, text="fix it", pid=PID, sid=SID, **env) -> str:
        return self.call(
            {"hook_event_name": "UserPromptSubmit", "session_id": sid, "prompt_id": pid, "prompt": text}, **env
        )

    def tool(self, name="Edit", path="/repo/a.py", pid=PID, sid=SID, **extra) -> str:
        key = "notebook_path" if name == "NotebookEdit" else "file_path"
        payload = {
            "hook_event_name": "PreToolUse", "session_id": sid, "prompt_id": pid,
            "tool_name": name, "tool_input": {key: path},
        }
        env = extra.pop("env", {})
        payload.update(extra)
        return self.call(payload, **env)

    def set_turn(self, role="judgment", pid=PID, sid=SID) -> None:
        d = self.state / "turns"
        d.mkdir(parents=True, mode=0o700, exist_ok=True)
        (d / f"{sid}.json").write_text(json.dumps({"prompt_id": pid, "role": role}))

    def denied(self, out: str) -> str | None:
        if not out.strip():
            return None
        h = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(h["hookEventName"], "PreToolUse")
        self.assertEqual(h["permissionDecision"], "deny")
        return h["permissionDecisionReason"]

    def log(self) -> list[dict]:
        p = self.state / "pilotfish-guard.jsonl"
        return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []

    def test_subagent_allowed(self) -> None:
        self.prompt()
        self.set_turn()
        self.assertEqual(self.tool(agent_id="a1", agent_type="executor"), "")
        self.assertEqual(self.log()[-1]["event"], "UserPromptSubmit")

    def test_r1_deny_for_judgment_and_mechanical(self) -> None:
        self.prompt()
        self.set_turn("judgment")
        reason = self.denied(self.tool())
        self.assertIn("`executor`", reason)
        self.assertIn("#direct", reason)
        self.set_turn_file("mechanical")
        self.assertIn("`mech-executor`", self.denied(self.tool()))
        self.assertEqual(self.log()[-1]["rule"], "R1")

    def set_turn_file(self, role) -> None:
        (self.state / "turns" / f"{SID}.json").write_text(json.dumps({"prompt_id": PID, "role": role}))

    def test_other_roles_do_not_trigger_r1(self) -> None:
        self.prompt()
        self.set_turn("parent_local")
        self.assertIsNone(self.denied(self.tool()))

    def test_agent_then_edit_allowed(self) -> None:
        self.prompt()
        self.set_turn()
        self.assertIsNotNone(self.denied(self.tool()))
        self.assertEqual(self.tool("Agent", tool_input={"prompt": "x"}), "")
        self.assertEqual(self.tool(), "")
        self.assertEqual(self.tool("Workflow"), "")

    def test_direct_allows_and_token_is_standalone(self) -> None:
        self.prompt("改一下 #direct")
        self.set_turn()
        self.assertEqual(self.tool(), "")
        self.prompt("see #directory now")
        self.assertIsNotNone(self.denied(self.tool()))

    def test_r2_on_third_distinct_file_and_repeat_not_counted(self) -> None:
        self.prompt()
        for p in ("/r/a.py", "/r/a.py", "/r/b.py", "/r/a.py"):
            self.assertEqual(self.tool(path=p), "")
        reason = self.denied(self.tool(path="/r/c.py"))
        self.assertIn("2 個檔案", reason)
        self.assertEqual(self.log()[-1]["rule"], "R2")
        self.assertEqual(self.log()[-1]["file"], "c.py")

    def test_max_files_env(self) -> None:
        self.prompt()
        self.assertEqual(self.tool(path="/r/a.py", env={"PILOTFISH_GUARD_MAX_FILES": "1"}), "")
        self.assertIsNotNone(self.denied(self.tool(path="/r/b.py", env={"PILOTFISH_GUARD_MAX_FILES": "1"})))

    def test_new_prompt_id_resets(self) -> None:
        self.prompt()
        self.tool(path="/r/a.py")
        self.tool(path="/r/b.py")
        self.assertEqual(self.tool(path="/r/c.py", pid="prompt-2"), "")
        self.set_turn(pid=PID)  # turn 檔屬於舊一輪，不影響新一輪
        self.assertEqual(self.tool(path="/r/d.py", pid="prompt-2"), "")

    def test_exempt_paths_not_counted(self) -> None:
        self.prompt()
        self.set_turn()
        for p in ("/tmp/x", "/private/tmp/x", "/var/folders/x/T/y", "/Users/m/.claude/projects/p/memory/m.md",
                  "/repo/.ai/CURRENT.md"):
            self.assertEqual(self.tool(path=p), "", p)
        st = json.loads((self.state / "guard" / f"{SID}.json").read_text())
        self.assertEqual(st["edited"], [])

    def test_notebook_path(self) -> None:
        self.prompt()
        self.set_turn()
        self.assertIsNotNone(self.denied(self.tool("NotebookEdit", "/r/n.ipynb")))

    def test_other_tools_ignored(self) -> None:
        self.prompt()
        self.set_turn()
        self.assertEqual(self.tool("Bash", tool_input={"command": "ls"}), "")

    def test_shadow_no_output_but_logged(self) -> None:
        self.prompt()
        self.set_turn()
        self.assertEqual(self.tool(env={"PILOTFISH_GUARD": "shadow"}), "")
        self.assertEqual(self.log()[-1]["decision"], "would_deny")

    def test_off(self) -> None:
        self.prompt(PILOTFISH_GUARD="off")
        self.assertFalse(self.state.exists())
        self.set_turn()
        self.assertEqual(self.tool(env={"PILOTFISH_GUARD": "off"}), "")

    def test_bad_json_fail_open(self) -> None:
        self.assertEqual(self.call(raw=b"{nope"), "")
        self.assertEqual(self.call(raw=b"[]"), "")
        self.assertEqual(self.call(raw=b""), "")

    def test_invalid_ids_write_nothing(self) -> None:
        self.prompt(sid="../evil")
        self.prompt(sid="a/b")
        self.prompt(pid="p q")
        self.assertEqual(self.tool(sid="../evil"), "")
        self.assertFalse(self.state.exists())

    def test_log_has_no_prompt_and_only_basename(self) -> None:
        self.prompt("secret words #direct")
        self.tool(path="/very/private/dir/a.py")
        text = (self.state / "pilotfish-guard.jsonl").read_text()
        self.assertNotIn("secret", text)
        self.assertNotIn("/very/private", text)

    def test_files_are_private(self) -> None:
        self.prompt()
        f = self.state / "guard" / f"{SID}.json"
        self.assertEqual(f.stat().st_mode & 0o777, 0o600)
        self.assertEqual(f.parent.stat().st_mode & 0o777, 0o700)

    def test_symlinked_guard_dir_refused(self) -> None:
        self.state.mkdir(parents=True, mode=0o700)
        target = self.home / "elsewhere"
        target.mkdir()
        (self.state / "guard").symlink_to(target)
        self.prompt()
        self.assertEqual(list(target.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
