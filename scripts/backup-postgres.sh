#!/usr/bin/env bash
# backup-postgres.sh — pg_dump daily with 7-day rotation + optional S3 copy.
#
# Matching guide: https://enterno.io/s/how-to-postgresql-backups
#
# Env:
#   DB_NAME      required   db to dump (one db per run — call twice for more)
#   DB_USER      optional   default postgres
#   BACKUP_DIR   optional   default /var/backups/postgres
#   KEEP_DAYS    optional   default 7
#   S3_BUCKET    optional   e.g. s3://my-bucket/pg — needs awscli + creds
#
# Usage:
#   sudo DB_NAME=app0 /opt/oss-samples/backup-postgres.sh
#   # wire to crontab at 02:00 daily

set -euo pipefail

[[ -n "${DB_NAME:-}" ]] || { echo "DB_NAME var required"; exit 1; }

DB_USER="${DB_USER:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/postgres}"
KEEP_DAYS="${KEEP_DAYS:-7}"
S3_BUCKET="${S3_BUCKET:-}"

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%F_%H%M%S)
OUT="${BACKUP_DIR}/${DB_NAME}_${STAMP}.sql.gz"

echo "→ dumping ${DB_NAME} to ${OUT}"
sudo -u "$DB_USER" pg_dump \
  --format=plain \
  --no-owner --no-privileges \
  --clean --if-exists \
  "$DB_NAME" | gzip -9 > "$OUT"

# Rotate locally
echo "→ rotating (keep ${KEEP_DAYS} days)"
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -type f -mtime "+${KEEP_DAYS}" -delete

# Offsite
if [[ -n "$S3_BUCKET" ]]; then
  if command -v aws >/dev/null; then
    echo "→ uploading to ${S3_BUCKET}"
    aws s3 cp "$OUT" "${S3_BUCKET}/"
  else
    echo "   awscli not installed — skipping S3. Install: apt-get install awscli"
  fi
fi

echo "✓ Backup done: $(du -h "$OUT" | cut -f1) at ${OUT}"
