#!/bin/bash
# SSH Remote File Edit Helper
# Pull a remote file, ready for local editing, then push back
# Usage:
#   ssh_edit.sh pull <remote_path>       - Download for editing
#   ssh_edit.sh push <remote_path>       - Upload edited file back
#   ssh_edit.sh diff <remote_path>       - Show changes before pushing

set -euo pipefail

CONFIG_FILE="/sessions/great-charming-cerf/ssh_config.env"
WORK_DIR="/sessions/great-charming-cerf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: No SSH config found. Run ssh_connect.sh first."
  exit 1
fi

source "$CONFIG_FILE"

ACTION="${1:?Usage: ssh_edit.sh <pull|push|diff> <remote_path>}"
REMOTE_PATH="${2:?Missing remote file path}"

# Derive local filename from remote path
LOCAL_FILE="$WORK_DIR/$(basename "$REMOTE_PATH")"
BACKUP_FILE="${LOCAL_FILE}.original"

case "$ACTION" in
  pull)
    echo "Downloading $REMOTE_PATH ..."
    scp -i "$SSH_KEY" -P "$SSH_PORT" "$SSH_USER@$SSH_HOST:$REMOTE_PATH" "$LOCAL_FILE"
    # Keep a copy of the original for diffing
    cp "$LOCAL_FILE" "$BACKUP_FILE"
    echo "File saved to: $LOCAL_FILE"
    echo "Original backup: $BACKUP_FILE"
    echo "Edit the file locally, then run: ssh_edit.sh push $REMOTE_PATH"
    ;;

  diff)
    if [ ! -f "$BACKUP_FILE" ]; then
      echo "No original backup found. Cannot diff."
      exit 1
    fi
    echo "Changes made to $(basename "$REMOTE_PATH"):"
    diff --color=auto "$BACKUP_FILE" "$LOCAL_FILE" || true
    ;;

  push)
    if [ ! -f "$LOCAL_FILE" ]; then
      echo "ERROR: Local file $LOCAL_FILE not found. Did you pull first?"
      exit 1
    fi
    # Show diff first
    if [ -f "$BACKUP_FILE" ]; then
      echo "=== Changes to be applied ==="
      diff --color=auto "$BACKUP_FILE" "$LOCAL_FILE" || true
      echo "=== End of changes ==="
    fi
    # Create remote backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "Creating remote backup: ${REMOTE_PATH}.bak.${TIMESTAMP}"
    ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
      "cp '$REMOTE_PATH' '${REMOTE_PATH}.bak.${TIMESTAMP}'" 2>/dev/null || echo "(backup skipped - file may not exist yet)"
    # Upload
    echo "Uploading to $REMOTE_PATH ..."
    scp -i "$SSH_KEY" -P "$SSH_PORT" "$LOCAL_FILE" "$SSH_USER@$SSH_HOST:$REMOTE_PATH"
    echo "Done! File updated on remote server."
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Usage: ssh_edit.sh <pull|push|diff> <remote_path>"
    exit 1
    ;;
esac
