#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

# Menu entry point for setup.sh, which runs scripts without arguments: install
# the computer-use driver and the desktop-ops service, then register both MCP
# servers. Idempotent; the work and its checks live in setup_computer_use.sh.

platform_guard "Computer use MCP (open-computer-use + desktop-ops)" darwin

SETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup_computer_use.sh"

/bin/bash "$SETUP" --install
/bin/bash "$SETUP" --apply
