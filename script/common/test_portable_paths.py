#!/usr/bin/env python3
"""portable_paths.py 的回歸測試：python3 script/common/test_portable_paths.py"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import portable_paths as pp  # noqa: E402


class PortableCommand(unittest.TestCase):
    def test_bare_path_uses_tilde(self):
        self.assertEqual(
            pp.portable_command("python3 /Users/miyago/.local/share/shoal/guard/shoal_guard.py --host claude"),
            "python3 ~/.local/share/shoal/guard/shoal_guard.py --host claude",
        )

    def test_linux_home(self):
        self.assertEqual(pp.portable_command("bash /home/miyago/x.sh"), "bash ~/x.sh")

    def test_single_quotes_become_double(self):
        self.assertEqual(
            pp.portable_command("bash '/Users/miyago/.gemini/config/hooks/a.sh' session"),
            'bash "$HOME/.gemini/config/hooks/a.sh" session',
        )

    def test_single_quotes_with_shell_metachar_left_alone(self):
        cmd = "echo '/Users/miyago/$x'"
        self.assertEqual(pp.portable_command(cmd), cmd)

    def test_inside_double_quotes_uses_home_var(self):
        self.assertEqual(pp.portable_command('cat "/home/miyago/a b"'), 'cat "$HOME/a b"')

    def test_assignment_keeps_tilde(self):
        self.assertEqual(pp.portable_command("f=/Users/miyago/a; echo hi"), "f=~/a; echo hi")

    def test_mid_word_uses_home_var(self):
        self.assertEqual(pp.portable_command("x file:///Users/miyago/a.js"), "x file://$HOME/a.js")

    def test_orca_style_guarded_command(self):
        cmd = "if [ -f '/Users/miyago/.orca/h.sh' ] && [ -x '/Users/miyago/.orca/h.sh' ]; then /bin/sh '/Users/miyago/.orca/h.sh'; fi"
        self.assertEqual(
            pp.portable_command(cmd),
            'if [ -f "$HOME/.orca/h.sh" ] && [ -x "$HOME/.orca/h.sh" ]; then /bin/sh "$HOME/.orca/h.sh"; fi',
        )

    def test_path_fragments_are_not_home(self):
        for text in ('"$WORK/home/elsewhere"', "/some/not/home/directory", "${X}/Users/a", "/home/linuxbrew/.linuxbrew/bin"):
            self.assertIsNone(pp.HOME_RE.search(text), text)

    def test_idempotent(self):
        once = pp.portable_command("bash '/Users/miyago/a.sh' && python3 /home/miyago/b.py")
        self.assertEqual(pp.portable_command(once), once)

    def test_already_portable_untouched(self):
        cmd = 'bash ~/dotfile/x.sh; f=~/y; [ -f "$f" ] || exit 0'
        self.assertEqual(pp.portable_command(cmd), cmd)

    def test_result_expands_in_sh(self):
        cmd = pp.portable_command("echo /Users/miyago/a '/Users/miyago/b c' \"/home/miyago/d\"")
        out = subprocess.run(["/bin/sh", "-c", cmd], capture_output=True, text=True, env={**os.environ, "HOME": "/h o"})
        self.assertEqual(out.stdout.strip(), "/h o/a /h o/b c /h o/d")


class FixAndCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "t@example.invalid")
        self.git("config", "user.name", "t")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_fix_only_touches_command_fields(self):
        path = self.write(
            "s.json",
            json.dumps({"dirs": ["/Users/miyago/keep"], "hooks": [{"command": "bash '/Users/miyago/a.sh'"}]}, indent=2),
        )
        self.assertTrue(pp.fix_file(path))
        data = json.loads(path.read_text())
        self.assertEqual(data["dirs"], ["/Users/miyago/keep"])
        self.assertEqual(data["hooks"][0]["command"], 'bash "$HOME/a.sh"')
        self.assertFalse(pp.fix_file(path))

    def test_fix_writes_through_symlink(self):
        real = self.write("real.json", json.dumps({"command": "sh /home/miyago/a"}))
        link = self.root / "link.json"
        link.symlink_to(real)
        self.assertTrue(pp.fix_file(link))
        self.assertTrue(link.is_symlink())
        self.assertEqual(json.loads(real.read_text())["command"], "sh ~/a")

    def test_check_reports_text_and_symlink(self):
        self.write("a.txt", "ok\npath /Users/miyago/x\n")
        self.write("docs/note.md", "/Users/miyago/history\n")
        (self.root / "abs").symlink_to("/Users/miyago/target")
        (self.root / "rel").symlink_to("a.txt")
        self.git("add", "-A")
        problems = pp.check(self.root, staged=False)
        self.assertEqual(len(problems), 2, problems)
        self.assertTrue(any(p.startswith("a.txt:2:") for p in problems))
        self.assertTrue(any(p.startswith("abs: symlink") for p in problems))

    def test_check_staged_reads_index(self):
        self.write("a.txt", "clean\n")
        self.git("add", "-A")
        self.git("commit", "-qm", "init")
        path = self.write("a.txt", "/home/miyago/x\n")
        self.git("add", "a.txt")
        path.write_text("clean again\n")
        self.assertEqual(len(pp.check(self.root, staged=True)), 1)
        self.assertEqual(pp.check(self.root, staged=False), [])

    def test_windows_path_detected(self):
        self.write("w.json", '{"p": "C:\\\\Users\\\\miyago\\\\x"}\n')
        self.git("add", "-A")
        self.assertEqual(len(pp.check(self.root, staged=False)), 1)


if __name__ == "__main__":
    unittest.main()
