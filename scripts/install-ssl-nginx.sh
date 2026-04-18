#!/usr/bin/env bash
# install-ssl-nginx.sh — bootstrap nginx with Let's Encrypt + HTTP/2 +
# HSTS + OCSP stapling for a single domain. Produces a production-
# grade server block and configures certbot auto-renewal.
#
# Matching guide: https://enterno.io/s/how-to-install-ssl-nginx
#
# Requires:  DOMAIN=example.com  EMAIL=admin@example.com

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
[[ -n "${DOMAIN:-}" ]] || { echo "DOMAIN var required"; exit 1; }
EMAIL="${EMAIL:-admin@${DOMAIN}}"

DRY="${DRY_RUN:-0}"
run() { [[ "$DRY" == "1" ]] && echo "[dry-run] $*" || eval "$*"; }

echo "→ installing nginx + certbot"
if ! command -v nginx >/dev/null; then
  run "apt-get update && apt-get install -y nginx certbot python3-certbot-nginx"
fi

CONF=/etc/nginx/sites-available/${DOMAIN}.conf
if [[ ! -f "$CONF" ]]; then
  echo "→ writing HTTP vhost (temporary — for ACME challenge)"
  run "cat > $CONF <<EOF
server {
  listen 80;
  server_name ${DOMAIN};
  root /var/www/${DOMAIN};
  location /.well-known/acme-challenge/ { allow all; }
  location / { return 301 https://\\\$host\\\$request_uri; }
}
EOF"
  run "mkdir -p /var/www/${DOMAIN}"
  run "ln -sf $CONF /etc/nginx/sites-enabled/${DOMAIN}.conf"
  run "nginx -t && systemctl reload nginx"
fi

echo "→ issuing Let's Encrypt cert"
run "certbot --nginx --non-interactive --agree-tos --email ${EMAIL} -d ${DOMAIN}"

echo "→ rewriting vhost with HTTP/2 + HSTS + OCSP stapling"
run "cat > $CONF <<EOF
server {
  listen 80;
  server_name ${DOMAIN};
  return 301 https://\\\$host\\\$request_uri;
}
server {
  listen 443 ssl http2;
  server_name ${DOMAIN};
  root /var/www/${DOMAIN};

  ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

  ssl_protocols       TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers off;
  ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
  ssl_session_cache   shared:SSL:10m;
  ssl_session_timeout 1d;
  ssl_session_tickets off;
  ssl_stapling        on;
  ssl_stapling_verify on;
  resolver            1.1.1.1 1.0.0.1 valid=300s;
  resolver_timeout    5s;

  add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;
  add_header X-Content-Type-Options       nosniff                  always;
  add_header Referrer-Policy              strict-origin-when-cross-origin always;

  location / { try_files \\\$uri \\\$uri/ =404; }
}
EOF"
run "nginx -t && systemctl reload nginx"

echo "✓ nginx + HTTPS ready for ${DOMAIN}"
echo "  Verify with: https://enterno.io/ssl?host=${DOMAIN}"
echo "              https://enterno.io/security?url=https://${DOMAIN}"
