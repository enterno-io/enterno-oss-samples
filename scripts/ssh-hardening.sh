#!/usr/bin/env bash
# ssh-hardening.sh — disable password + root login, force public-key
# auth, shorten idle timeout, enable fail2ban sshd jail.
#
# Matching guide: https://enterno.io/s/how-to-ssh-hardening
#
# Idempotent. Takes a backup before rewriting /etc/ssh/sshd_config.
# DRY_RUN=1 to print without applying.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

DRY="${DRY_RUN:-0}"
CFG=/etc/ssh/sshd_config
STAMP=$(date +%F)
BACKUP="${CFG}.bak-${STAMP}"

run() {
  if [[ "$DRY" == "1" ]]; then
    echo "[dry-run] $*"
  else
    eval "$*"
  fi
}

echo "→ backing up $CFG to $BACKUP"
run "cp -n $CFG $BACKUP"

# Rewrite or append each directive — sed -i handles existing values,
# grep/echo appends if missing.
hardening=(
  "PermitRootLogin no"
  "PasswordAuthentication no"
  "ChallengeResponseAuthentication no"
  "KbdInteractiveAuthentication no"
  "PubkeyAuthentication yes"
  "MaxAuthTries 3"
  "ClientAliveInterval 300"
  "ClientAliveCountMax 2"
  "LoginGraceTime 30"
  "X11Forwarding no"
  "AllowTcpForwarding no"
  "PermitEmptyPasswords no"
  "Protocol 2"
)
for line in "${hardening[@]}"; do
  key="${line%% *}"
  if grep -qE "^\s*#?\s*${key}\b" "$CFG"; then
    run "sed -i 's|^\s*#\?\s*${key}\b.*|${line}|' $CFG"
  else
    run "echo '${line}' >> $CFG"
  fi
done

echo "→ validating sshd config"
run "sshd -t"

if command -v systemctl >/dev/null; then
  echo "→ reloading sshd"
  run "systemctl reload ssh || systemctl reload sshd"
fi

echo "→ enabling fail2ban sshd jail (if fail2ban installed)"
if command -v fail2ban-client >/dev/null; then
  JAIL=/etc/fail2ban/jail.d/sshd.local
  if [[ ! -f "$JAIL" ]]; then
    run "cat > $JAIL <<'EOF'
[sshd]
enabled = true
maxretry = 3
findtime = 5m
bantime = 1h
EOF"
    run "systemctl restart fail2ban"
  else
    echo "   jail already configured — leaving it alone"
  fi
else
  echo "   fail2ban not installed — skipping. Install: apt-get install fail2ban"
fi

echo "✓ SSH hardening complete. Backup at $BACKUP"
echo "  Verify you can still log in via key auth BEFORE closing this session."
