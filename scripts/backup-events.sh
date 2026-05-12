#!/bin/bash
# =============================================================
# backup-events.sh
# Backs up events.csv and n8n SQLite database.
# Run manually or via cron (e.g. daily at midnight).
# Keeps last 7 backups, compresses older ones.
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVENTS_FILE="${SCRIPT_DIR}/../events/events.csv"
BACKUP_DIR="${SCRIPT_DIR}/../events/backups"
N8N_DB_VOLUME="observability-stack_n8n_data"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
MAX_BACKUPS=7

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup..."

# Backup events.csv
if [[ -f "$EVENTS_FILE" ]]; then
    cp "$EVENTS_FILE" "${BACKUP_DIR}/events_${TIMESTAMP}.csv"
    gzip "${BACKUP_DIR}/events_${TIMESTAMP}.csv"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] events.csv backed up."
fi

# Backup n8n SQLite database from Docker volume
docker run --rm \
    -v "${N8N_DB_VOLUME}:/data:ro" \
    -v "${BACKUP_DIR}:/backup" \
    alpine \
    cp /data/database.sqlite "/backup/n8n_db_${TIMESTAMP}.sqlite" 2>/dev/null && \
    gzip "${BACKUP_DIR}/n8n_db_${TIMESTAMP}.sqlite" && \
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] n8n SQLite DB backed up." || \
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Could not backup n8n DB."

# Cleanup old backups — keep only last MAX_BACKUPS
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaning old backups (keeping last ${MAX_BACKUPS})..."
ls -t "${BACKUP_DIR}"/events_*.csv.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f || true
ls -t "${BACKUP_DIR}"/n8n_db_*.sqlite.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f || true

BACKUP_COUNT=$(ls "${BACKUP_DIR}"/*.gz 2>/dev/null | wc -l || echo 0)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup complete. Total backup files: ${BACKUP_COUNT}"
