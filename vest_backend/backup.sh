#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
REMOTE_HOST="192.168.0.10"
REMOTE_PATH="/srv/backups/vest"
REMOTE_USER="${BACKUP_REMOTE_USER:-backup-user}"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
CONTAINER_NAME="${BACKUP_CONTAINER_NAME:-vest-deploy-api-1}"
DB_CONTAINER_PATH="/app/data/vest.db"
RETENTION_DAYS=14
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILENAME="vest_${TIMESTAMP}.db"
LOCAL_TEMP_DIR="$(mktemp -d)"

trap 'rm -rf "${LOCAL_TEMP_DIR}"' EXIT

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── 1. Copy database from running container using SQLite backup ──────────────
log "Starting backup..."

# Use sqlite3 .backup inside the container to get a consistent snapshot
# This is safe even while the application is writing to the database
docker exec "${CONTAINER_NAME}" sqlite3 "${DB_CONTAINER_PATH}" ".backup '/tmp/vest_backup.db'"
docker cp "${CONTAINER_NAME}:/tmp/vest_backup.db" "${LOCAL_TEMP_DIR}/${BACKUP_FILENAME}"
docker exec "${CONTAINER_NAME}" rm -f /tmp/vest_backup.db

log "Database snapshot saved to ${LOCAL_TEMP_DIR}/${BACKUP_FILENAME}"

# ── 2. Compress the backup ───────────────────────────────────────────────────
gzip "${LOCAL_TEMP_DIR}/${BACKUP_FILENAME}"
BACKUP_FILE="${LOCAL_TEMP_DIR}/${BACKUP_FILENAME}.gz"
log "Compressed to ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"

# ── 3. Transfer to remote host ──────────────────────────────────────────────
log "Transferring to ${REMOTE_HOST}:${REMOTE_PATH}..."
ssh ${SSH_OPTS} "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_PATH}'"
rsync -az -e "ssh ${SSH_OPTS}" "${BACKUP_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"

log "Transfer complete"

# ── 4. Prune old backups on remote ──────────────────────────────────────────
log "Pruning backups older than ${RETENTION_DAYS} days on remote..."
ssh ${SSH_OPTS} "${REMOTE_USER}@${REMOTE_HOST}" \
    "find '${REMOTE_PATH}' -name 'vest_*.db.gz' -mtime +${RETENTION_DAYS} -delete"

log "Backup finished successfully: ${BACKUP_FILENAME}.gz"
