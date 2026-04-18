#!/usr/bin/env bash
# setup-fail2ban.sh — install fail2ban + three sensible default jails:
# sshd (brute-force), nginx-bad-bot (bad user-agent), nginx-limit-req
# (429 storms).
#
# Matching guide: https://enterno.io/s/how-to-setup-fail2ban
#
# Use DRY_RUN=1 to preview.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

DRY="${DRY_RUN:-0}"
run() { [[ "$DRY" == "1" ]] && echo "[dry-run] $*" || eval "$*"; }

echo "→ installing fail2ban (if missing)"
if ! command -v fail2ban-client >/dev/null; then
  run "apt-get update && apt-get install -y fail2ban"
fi

mkdir -p /etc/fail2ban/filter.d /etc/fail2ban/jail.d

# ── sshd jail
echo "→ enabling sshd jail"
run "cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 3
findtime = 5m
bantime  = 1h
EOF"

# ── nginx bad-bot filter + jail
echo "→ nginx bad-bot jail"
run "cat > /etc/fail2ban/filter.d/nginx-bad-bot.conf <<'EOF'
[Definition]
failregex = ^<HOST> -.*\"(?:GET|POST|HEAD).*\" .* \".*(ahrefsbot|semrushbot|mj12bot|dotbot|blexbot|mauibot|bytespider).*\"$
ignoreregex =
EOF"
run "cat > /etc/fail2ban/jail.d/nginx-bad-bot.local <<'EOF'
[nginx-bad-bot]
enabled  = true
filter   = nginx-bad-bot
logpath  = /var/log/nginx/access.log
maxretry = 1
findtime = 1m
bantime  = 24h
EOF"

# ── nginx limit_req storm jail
echo "→ nginx rate-limit jail"
run "cat > /etc/fail2ban/filter.d/nginx-limit-req.conf <<'EOF'
[Definition]
failregex = limiting requests, excess.*client: <HOST>
ignoreregex =
EOF"
run "cat > /etc/fail2ban/jail.d/nginx-limit-req.local <<'EOF'
[nginx-limit-req]
enabled  = true
filter   = nginx-limit-req
logpath  = /var/log/nginx/error.log
maxretry = 10
findtime = 10m
bantime  = 30m
EOF"

echo "→ restarting fail2ban"
run "systemctl enable --now fail2ban"
run "systemctl restart fail2ban"

echo "✓ Done. Check active jails: sudo fail2ban-client status"
