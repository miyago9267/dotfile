#!/bin/bash
# SSH Connection Setup & Test Script
# Usage: bash ssh_connect.sh <user> <host> <key_path> [port]

set -euo pipefail

SSH_USER="${1:?Usage: ssh_connect.sh <user> <host> <key_path> [port]}"
SSH_HOST="${2:?Missing host}"
SSH_KEY="${3:?Missing key path}"
SSH_PORT="${4:-22}"
CONFIG_FILE="/sessions/great-charming-cerf/ssh_config.env"

# Validate key file exists
if [ ! -f "$SSH_KEY" ]; then
  echo "ERROR: SSH key not found at $SSH_KEY"
  exit 1
fi

# Ensure proper permissions
chmod 600 "$SSH_KEY" 2>/dev/null || true

# Save config
cat > "$CONFIG_FILE" <<EOF
SSH_USER="$SSH_USER"
SSH_HOST="$SSH_HOST"
SSH_PORT="$SSH_PORT"
SSH_KEY="$SSH_KEY"
EOF

echo "Config saved to $CONFIG_FILE"

# Test connection
echo "Testing SSH connection to $SSH_USER@$SSH_HOST:$SSH_PORT ..."
if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes \
   -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
   "echo 'OK: Connected to $(hostname) as $(whoami)'"; then
  echo "Connection successful!"
else
  echo "ERROR: Connection failed. Check credentials, host, and firewall."
  exit 1
fi
