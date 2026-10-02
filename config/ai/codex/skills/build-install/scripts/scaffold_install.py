#!/usr/bin/env python3
"""Generate the standard AI + human install entrypoints for a project."""
from __future__ import annotations

import argparse
import re
import shlex
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_dir", type=Path)
    parser.add_argument("--name", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--install-url", required=True)
    parser.add_argument("--install-dir")
    parser.add_argument("--ref", default="main")
    parser.add_argument("--prerequisites", default="bash, git")
    parser.add_argument("--verify", default="<VERIFY_COMMAND>")
    parser.add_argument("--uninstall", default="Remove <INSTALL_DIR> and restore any documented backups.")
    parser.add_argument("--force", action="store_true", help="overwrite existing generated files")
    return parser.parse_args()


def render(template: str, values: dict[str, str]) -> str:
    for key, value in values.items():
        template = template.replace(f"<{key}>", value)
    return template


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9._-]+", "-", name.lower()).strip("-.")
    if not slug or slug == "..":
        raise SystemExit("project name must produce a safe install directory name")
    return slug


def main() -> int:
    args = parse_args()
    slug = slugify(args.name)
    install_dir = args.install_dir or f"${{HOME}}/.local/share/{slug}"
    uninstall = args.uninstall.replace("<INSTALL_DIR>", install_dir)
    skill_root = Path(__file__).resolve().parents[1]
    templates = skill_root / "assets"
    values = {
        "PROJECT_NAME": args.name,
        "REPOSITORY_URL": args.repo,
        "INSTALL_URL": args.install_url,
        "INSTALL_DIR": install_dir,
        "DEFAULT_REF": args.ref,
        "PREREQUISITES": args.prerequisites,
        "VERIFY_COMMAND": args.verify,
        "UNINSTALL_STEPS": uninstall,
        "PROJECT_NAME_SHELL": shlex.quote(args.name),
        "REPOSITORY_URL_SHELL": shlex.quote(args.repo),
        "DEFAULT_REF_SHELL": shlex.quote(args.ref),
        "INSTALL_DIR_SHELL": f'"${{HOME}}/.local/share/{slug}"' if not args.install_dir else shlex.quote(install_dir),
    }
    outputs = {
        "INSTALL.md": "INSTALL.md.tmpl",
        "INSTALL_PROMPT.md": "INSTALL_PROMPT.md.tmpl",
        "install.sh": "install.sh.tmpl",
    }
    args.project_dir.mkdir(parents=True, exist_ok=True)
    for output, source in outputs.items():
        destination = args.project_dir / output
        if destination.exists() and not args.force:
            raise SystemExit(f"refusing to overwrite {destination}; use --force")
        destination.write_text(render((templates / source).read_text(), values))
        if output == "install.sh":
            destination.chmod(0o755)
        print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
