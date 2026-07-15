#!/usr/bin/env bash
# GCP monthly billing report for iKala-resold accounts (dunqian2/dunqian5 - ikalatv).
# Scans ~/Downloads (or --src) for GCP console Cost Table CSV exports, builds one
# workbook per account+month (總表 / per-project sheets / 小計) plus a cross-month
# summary, verifies totals against each CSV's built-in Total row, and optionally
# uploads everything to Google Drive as native Google Sheets (idempotent: re-runs
# update the same Sheets in place).
#
# Usage:
#   bash ~/.claude/scripts/ikala-billing-report.sh                  # build only
#   bash ~/.claude/scripts/ikala-billing-report.sh --upload         # build + upload to「帳單」folder
#   bash ~/.claude/scripts/ikala-billing-report.sh --upload FOLDER_ID
#   bash ~/.claude/scripts/ikala-billing-report.sh --months 202607 --rate 32.1
#
# Upload needs a Drive-scoped gcloud token: gcloud auth login --enable-gdrive-access
set -euo pipefail
for py in "$HOME/.pyenv/shims/python3" python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
  if command -v "$py" >/dev/null 2>&1 && "$py" -c 'import openpyxl' 2>/dev/null; then
    exec "$py" "$(dirname "$0")/ikala-billing-report.py" "$@"
  fi
done
echo "error: no python3 with openpyxl found (pip install openpyxl)" >&2
exit 1
