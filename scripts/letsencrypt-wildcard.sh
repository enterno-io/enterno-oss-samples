#!/usr/bin/env bash
# letsencrypt-wildcard.sh — issue a *.example.com certificate via DNS-01
# through Cloudflare, install it into nginx, and wire auto-renewal.
#
# Matching guide: https://enterno.io/s/how-to-lets-encrypt-wildcard
#
# Requirements:
#   - certbot with the DNS plugin for your provider
#   - DNS API token exported as CF_TOKEN (Cloudflare example)
#   - DOMAIN var set (e.g. example.com)
#
# Usage:
#   sudo DOMAIN=example.com CF_TOKEN=xxx ./letsencrypt-wildcard.sh
#   sudo DRY_RUN=1 DOMAIN=example.com CF_TOKEN=xxx ./letsencrypt-wildcard.sh

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
[[ -n "${DOMAIN:-}" ]] || { echo "DOMAIN var required"; exit 1; }
[[ -n "${CF_TOKEN:-}" ]] || { echo "CF_TOKEN var required"; exit 1; }

DRY="${DRY_RUN:-0}"
run() { [[ "$DRY" == "1" ]] && echo "[dry-run] $*" || eval "$*"; }

echo "→ installing certbot + cloudflare plugin (if missing)"
if ! command -v certbot >/dev/null; then
  run "apt-get update && apt-get install -y certbot python3-certbot-dns-cloudflare"
fi

CRED=/etc/letsencrypt/cloudflare.ini
if [[ ! -f "$CRED" ]]; then
  echo "→ writing Cloudflare credentials to $CRED (perms 600)"
  run "umask 177 && printf 'dns_cloudflare_api_token = %s\n' '${CF_TOKEN}' > $CRED"
fi

echo "→ requesting *.${DOMAIN} + ${DOMAIN} certificate"
run "certbot certonly --non-interactive --agree-tos \
  --dns-cloudflare --dns-cloudflare-credentials $CRED --dns-cloudflare-propagation-seconds 30 \
  -d ${DOMAIN} -d '*.${DOMAIN}' \
  --email admin@${DOMAIN}"

echo "→ setting up auto-renewal cron (2:30 daily)"
CRON=/etc/cron.d/certbot-renew
if [[ ! -f "$CRON" ]]; then
  run "cat > $CRON <<'EOF'
30 2 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx'
EOF"
fi

echo "✓ Wildcard cert for ${DOMAIN} ready."
echo "  Verify with: https://enterno.io/ssl?host=${DOMAIN}"
