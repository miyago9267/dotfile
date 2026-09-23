from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOTFILE = ROOT.parents[1]
AGENTS_DIR = ROOT / "templates" / "agents"
RULE_FILE = ROOT / "templates" / "rules" / "pilotfish-agy.md"
SKILL_FILE = ROOT / "templates" / "skills" / "pilotfish-orchestration" / "SKILL.md"
SETUP = DOTFILE / "script" / "common" / "setup_gemini.sh"

# role -> (tier, capability)
ROUTING = {
    "scout": ("flash", "read-only"),
    "plan-verifier": ("pro", "read-only"),
    "security-reviewer": ("pro", "read-only"),
    "mech-executor": ("flash", "all"),
    "executor": ("pro", "all"),
    "verifier": ("pro", "execute"),
    "security-executor": ("pro", "all"),
}

READ_TOOLS = {
    "view_file", "grep_search", "find_by_name", "list_dir",
    "codebase_search", "read_url_content", "search_web", "send_message",
}
EXEC_TOOLS = {"run_command"}
EDIT_TOOLS = {
    "write_to_file", "replace_file_content", "multi_replace_file_content",
    "edit_file", "create_file", "delete_file", "write_file",
}
DELEGATION_TOOLS = {"invoke_subagent", "define_subagent", "manage_subagents"}

# 常駐 rule 預算：R6 要求 < 1,500 tokens；中英混排以 3.5 chars/token 保守估計。
RULE_CHAR_BUDGET = 5000


def parse_agent(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not match:
        raise AssertionError(f"missing frontmatter in {path}")
    head, body = match.groups()
    meta: dict = {}
    key = None
    for line in head.splitlines():
        item = re.match(r"^\s+-\s+(\S+)\s*$", line)
        if item and key:
            meta.setdefault(key, []).append(item.group(1))
            continue
        pair = re.match(r"^(\w+):\s*(.*)$", line)
        if pair:
            key, value = pair.groups()
            if value:
                meta[key] = value.strip()
    return meta, body


class AgentTemplateTests(unittest.TestCase):
    def test_exactly_seven_roles(self) -> None:
        found = {p.parent.name for p in AGENTS_DIR.glob("*/agent.md")}
        self.assertEqual(found, set(ROUTING))

    def test_frontmatter_contract(self) -> None:
        for role, (tier, capability) in ROUTING.items():
            with self.subTest(role=role):
                meta, body = parse_agent(AGENTS_DIR / role / "agent.md")
                self.assertEqual(meta.get("name"), role)
                self.assertTrue(meta.get("description"))
                # 具體 model ID 會讓 agent 靜默失效，只能用 tier。
                self.assertEqual(meta.get("model"), tier)
                self.assertRegex(body, r"(?m)^# Agent System Instructions\s*$")
                self.assertIn("Never spawn further subagents", body)

    def test_capability_tools(self) -> None:
        for role, (_, capability) in ROUTING.items():
            with self.subTest(role=role):
                meta, _ = parse_agent(AGENTS_DIR / role / "agent.md")
                tools = set(meta.get("tools", []))
                self.assertFalse(tools & DELEGATION_TOOLS)
                if capability == "read-only":
                    self.assertTrue(tools)
                    self.assertLessEqual(tools, READ_TOOLS)
                elif capability == "execute":
                    self.assertIn("run_command", tools)
                    self.assertLessEqual(tools, READ_TOOLS | EXEC_TOOLS)
                    self.assertFalse(tools & EDIT_TOOLS)
                else:
                    # 執行角色沿用 agy 預設工具集，不收窄。
                    self.assertNotIn("tools", meta)


class PolicyTests(unittest.TestCase):
    def test_rule_is_short_and_names_roles_only(self) -> None:
        text = RULE_FILE.read_text(encoding="utf-8")
        self.assertLess(len(text), RULE_CHAR_BUDGET)
        for role in ROUTING:
            self.assertIn(f"`{role}`", text)
        self.assertIn("pilotfish-orchestration", text)
        self.assertNotRegex(text, r"gemini-\d|claude-|model: (flash|pro)")

    def test_skill_frontmatter_and_verdicts(self) -> None:
        text = SKILL_FILE.read_text(encoding="utf-8")
        self.assertRegex(text, r"(?m)^name: pilotfish-orchestration$")
        self.assertRegex(text, r"(?m)^description: .+")
        for token in ("READY", "REVISE", "CONFIRMED", "REFUTED", "INCONCLUSIVE",
                      "invoke_subagent"):
            self.assertIn(token, text)
        self.assertNotRegex(text, r"gemini-\d|claude-")


class InstallTests(unittest.TestCase):
    def test_setup_links_agents_skill_and_rule(self) -> None:
        with tempfile.TemporaryDirectory() as home:
            env = dict(os.environ, HOME=home)
            subprocess.run(["bash", str(SETUP)], env=env, check=True,
                           capture_output=True)
            base = Path(home) / ".gemini" / "config"
            for role in ROUTING:
                link = base / "agents" / role
                self.assertTrue(link.is_symlink(), role)
                self.assertEqual(link.resolve(), (AGENTS_DIR / role).resolve())
            skill = base / "skills" / "pilotfish-orchestration"
            self.assertEqual(skill.resolve(), SKILL_FILE.parent.resolve())
            # Gemini CLI 沒有這些角色，skill 不裝進 ~/.gemini/skills。
            self.assertFalse((Path(home) / ".gemini" / "skills" /
                              "pilotfish-orchestration").exists())
            rules = (Path(home) / ".gemini" / "GEMINI.md").read_text(encoding="utf-8")
            self.assertIn("<!-- pilotfish-agy:begin -->", rules)


if __name__ == "__main__":
    unittest.main()
