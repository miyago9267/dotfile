---
name: ssh-remote
description: |
  SSH remote server operations — connect to remote machines, read/edit/create files, upload/download via SCP, and execute commands over SSH. Use this skill whenever the user mentions SSH, remote server, VPS, connecting to a server, editing remote files, deploying config changes, or any task involving a remote Linux/Unix machine. Also trigger when the user says things like "go to my server and change X", "update the config on production", "check the logs on my VPS", or "copy files to/from my server". This skill handles the full lifecycle: establishing connections, navigating the remote filesystem, editing files in-place, transferring files, and running commands — all through SSH from the Cowork sandbox.
---

# SSH Remote Operations

This skill enables Claude to connect to remote servers via SSH and perform file operations, command execution, and file transfers — all from within Cowork mode.

## Prerequisites

The Cowork VM has `ssh`, `scp`, and `sftp` available. The user needs to provide:

1. **SSH Key**: Must be accessible to the VM. The user can either:
   - Select a folder containing their `.ssh` directory (via Cowork's folder picker)
   - Or paste their private key content so Claude can write a temporary key file

2. **Connection details**: hostname/IP, username, and optionally a port (default 22)

## Setup Flow

When the user wants to connect to a remote server, follow these steps:

### Step 1: Gather connection info

Ask the user for:
- **Host**: IP address or hostname
- **Username**: SSH login user
- **Port**: defaults to 22
- **Key location**: Ask if they have their SSH key accessible. If not, they can either:
  - Use the `request_cowork_directory` tool to mount a folder containing their `.ssh/` directory
  - Paste the key content (Claude writes it to a temp file with `chmod 600`)

### Step 2: Write the connection config

Save connection details to `/sessions/great-charming-cerf/ssh_config.env` so subsequent commands can reuse them without asking again:

```bash
SSH_USER="username"
SSH_HOST="1.2.3.4"
SSH_PORT="22"
SSH_KEY="/path/to/key"
```

### Step 3: Test the connection

Run a quick connectivity check:
```bash
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "echo 'Connection OK: $(hostname)'"
```

Use `-o StrictHostKeyChecking=accept-new` to auto-accept new host keys (first connect). If it fails, help the user debug (wrong key, firewall, etc.).

## Core Operations

Once connected, here's how to perform each operation. Always source the config first:

```bash
source /sessions/great-charming-cerf/ssh_config.env
```

### Reading remote files

```bash
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cat /path/to/file"
```

For large files, use `head`, `tail`, or `less`-style pagination:
```bash
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "head -n 100 /path/to/file"
```

### Editing remote files

The most reliable approach is **pull → edit locally → push back**:

1. Download the file:
   ```bash
   scp -i "$SSH_KEY" -P "$SSH_PORT" "$SSH_USER@$SSH_HOST:/remote/path/file.conf" /sessions/great-charming-cerf/file.conf
   ```

2. Edit locally using Claude's `Read` and `Edit` tools (which have good diffing and are safe)

3. Push back:
   ```bash
   scp -i "$SSH_KEY" -P "$SSH_PORT" /sessions/great-charming-cerf/file.conf "$SSH_USER@$SSH_HOST:/remote/path/file.conf"
   ```

For small, targeted edits you can also use `sed` remotely:
```bash
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "sed -i 's/old_value/new_value/g' /path/to/file"
```

But prefer the pull-edit-push approach — it lets you review changes with the user before overwriting.

### Creating remote files

Write the file locally, then SCP it up:
```bash
scp -i "$SSH_KEY" -P "$SSH_PORT" /sessions/great-charming-cerf/newfile.txt "$SSH_USER@$SSH_HOST:/remote/destination/"
```

### Uploading / Downloading files

**Upload (local → remote):**
```bash
scp -i "$SSH_KEY" -P "$SSH_PORT" /local/path "$SSH_USER@$SSH_HOST:/remote/path"
```

**Download (remote → local):**
```bash
scp -i "$SSH_KEY" -P "$SSH_PORT" "$SSH_USER@$SSH_HOST:/remote/path" /sessions/great-charming-cerf/mnt/outputs/
```
Always download to `mnt/outputs/` so the user can access the file.

**Recursive directory transfer:**
```bash
scp -r -i "$SSH_KEY" -P "$SSH_PORT" "$SSH_USER@$SSH_HOST:/remote/dir/" /sessions/great-charming-cerf/mnt/outputs/dir/
```

### Executing remote commands

```bash
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "command here"
```

For multi-line or complex commands, use a heredoc:
```bash
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" bash <<'REMOTE_EOF'
  cd /var/www
  git pull origin main
  systemctl restart nginx
REMOTE_EOF
```

### Listing and navigating

```bash
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "ls -la /path/"
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "find /path -name '*.conf' -type f"
```

## Safety Guidelines

Remote operations can be destructive, so follow these principles:

1. **Always confirm before writing.** Before pushing an edited file back or running a command that modifies state (rm, mv, sed -i, systemctl, etc.), show the user what will change and get explicit confirmation.

2. **Create backups.** Before overwriting a config file, back it up:
   ```bash
   ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cp /path/file.conf /path/file.conf.bak.$(date +%Y%m%d_%H%M%S)"
   ```

3. **Show diffs.** After editing a file locally, show the user what changed before pushing:
   ```bash
   diff /sessions/great-charming-cerf/file.conf.original /sessions/great-charming-cerf/file.conf
   ```

4. **Never store credentials in outputs.** SSH keys and connection details stay in the session working directory, never in `mnt/outputs/`.

5. **Be careful with sudo.** If a command needs sudo, tell the user and confirm. Some servers have passwordless sudo; if not, the user may need to run it themselves.

## Convenience Helper

For repetitive sessions, you can define a shell function:

```bash
remote() {
  source /sessions/great-charming-cerf/ssh_config.env
  ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$@"
}
```

Then just: `remote "ls -la /etc/nginx/"`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Permission denied (publickey)` | Wrong key, or key not `chmod 600`, or server doesn't accept this key |
| `Connection timed out` | Check IP/port, firewall rules, server is running |
| `Host key verification failed` | Use `-o StrictHostKeyChecking=accept-new` or clear `~/.ssh/known_hosts` |
| `No such file or directory` | Verify the remote path with `ls` before editing |
| SCP port flag is `-P` not `-p` | `scp` uses uppercase `-P` for port; `ssh` uses lowercase `-p` |

## Multi-Server Support

If the user works with multiple servers, save separate config files:
```
/sessions/great-charming-cerf/ssh_config_production.env
/sessions/great-charming-cerf/ssh_config_staging.env
```

Ask which server they want to work with if it's ambiguous.
