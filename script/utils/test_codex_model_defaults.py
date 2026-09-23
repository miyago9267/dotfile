import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from codex_model_defaults import sync_config


DEFAULTS = Path(__file__).parents[2] / "config/ai/codex/model-defaults.toml"


class CodexModelDefaultsTests(unittest.TestCase):
    def test_updates_only_managed_root_values_and_keeps_backup(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.toml"
            config.write_text(
                'model = "gpt-6-luna" # old main model\n'
                'model_reasoning_effort = "max"\n'
                'plugin_setting = "preserve-me"\n'
                "\n[agents]\nmodel = \"gpt-6-sol\"\n",
                encoding="utf-8",
            )

            status, backup = sync_config(config, DEFAULTS)

            self.assertEqual(status, "updated")
            self.assertIsNotNone(backup)
            self.assertIn('model = "gpt-6-luna" # old main model', backup.read_text())
            parsed = tomllib.loads(config.read_text())
            self.assertEqual(parsed["model"], "gpt-6-sol")
            self.assertEqual(parsed["model_reasoning_effort"], "medium")
            self.assertEqual(parsed["plugin_setting"], "preserve-me")
            self.assertEqual(parsed["agents"]["model"], "gpt-6-sol")

    def test_creates_minimal_config_if_missing(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.toml"

            status, backup = sync_config(config, DEFAULTS)

            self.assertEqual(status, "updated")
            self.assertIsNone(backup)
            self.assertEqual(
                tomllib.loads(config.read_text()),
                {"model": "gpt-6-sol", "model_reasoning_effort": "medium"},
            )

    def test_does_not_follow_symlinked_config(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            actual = root / "actual.toml"
            actual.write_text('model = "gpt-6-luna"\n', encoding="utf-8")
            link = root / "config.toml"
            link.symlink_to(actual)

            status, backup = sync_config(link, DEFAULTS)

            self.assertEqual(status, "skipped symlink")
            self.assertIsNone(backup)
            self.assertEqual(tomllib.loads(actual.read_text())["model"], "gpt-6-luna")


if __name__ == "__main__":
    unittest.main()
