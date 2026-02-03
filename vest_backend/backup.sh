#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${BACKUP_ENV_FILE:-${SCRIPT_DIR}/.env}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

[[ -f "${ENV_FILE}" ]] || { echo "Missing ${ENV_FILE}. Copy .env.example to .env and fill it out." >&2; exit 1; }
set -a
# shellcheck source=/dev/null
. "${ENV_FILE}"
set +a

: "${VEST_BACKUP_REMOTE_HOST:?Set VEST_BACKUP_REMOTE_HOST in .env}"
: "${VEST_BACKUP_REMOTE_USER:?Set VEST_BACKUP_REMOTE_USER in .env}"
: "${VEST_BACKUP_REMOTE_PATH:?Set VEST_BACKUP_REMOTE_PATH in .env}"
: "${VEST_BACKUP_CONTAINER_NAME:?Set VEST_BACKUP_CONTAINER_NAME in .env}"
: "${VEST_DB_CONTAINER_PATH:?Set VEST_DB_CONTAINER_PATH in .env}"
: "${VEST_BACKUP_RETENTION_DAYS:?Set VEST_BACKUP_RETENTION_DAYS in .env}"
: "${VEST_BACKUP_TMP_DIR:?Set VEST_BACKUP_TMP_DIR in .env}"
: "${VEST_BACKUP_SSH_OPTS:?Set VEST_BACKUP_SSH_OPTS in .env}"
: "${VEST_BACKUP_CONTAINER_TEMP_PATH:?Set VEST_BACKUP_CONTAINER_TEMP_PATH in .env}"
: "${VEST_BACKUP_FILENAME_PREFIX:?Set VEST_BACKUP_FILENAME_PREFIX in .env}"

# ── Configuration ────────────────────────────────────────────────────────────
REMOTE_HOST="${VEST_BACKUP_REMOTE_HOST}"
REMOTE_PATH="${VEST_BACKUP_REMOTE_PATH}"
REMOTE_USER="${VEST_BACKUP_REMOTE_USER}"
SSH_OPTS="${VEST_BACKUP_SSH_OPTS}"
CONTAINER_NAME="${VEST_BACKUP_CONTAINER_NAME}"
DB_CONTAINER_PATH="${VEST_DB_CONTAINER_PATH}"
RETENTION_DAYS="${VEST_BACKUP_RETENTION_DAYS}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILENAME="${VEST_BACKUP_FILENAME_PREFIX}_${TIMESTAMP}.db"

BASE_TMP_DIR="${VEST_BACKUP_TMP_DIR}"
mkdir -p "${BASE_TMP_DIR}"
LOCAL_TEMP_DIR="$(mktemp -d -p "${BASE_TMP_DIR}" vest_backup.XXXXXX)"
mkdir -p "${LOCAL_TEMP_DIR}"
[[ -d "${LOCAL_TEMP_DIR}" ]] || { echo "Temp dir missing: ${LOCAL_TEMP_DIR}" >&2; exit 1; }
log "Using temp dir: ${LOCAL_TEMP_DIR}"

trap 'rm -rf "${LOCAL_TEMP_DIR}"' EXIT

# ── 1. Copy database from running container using SQLite backup ──────────────
log "Starting backup..."

# Use sqlite3 .backup inside the container to get a consistent snapshot
# This is safe even while the application is writing to the database
docker exec "${CONTAINER_NAME}" sqlite3 "${DB_CONTAINER_PATH}" ".backup '${VEST_BACKUP_CONTAINER_TEMP_PATH}'"
[[ -d "${LOCAL_TEMP_DIR}" ]] || { echo "Temp dir missing before copy: ${LOCAL_TEMP_DIR}" >&2; exit 1; }
docker cp "${CONTAINER_NAME}:${VEST_BACKUP_CONTAINER_TEMP_PATH}" "${LOCAL_TEMP_DIR}/${BACKUP_FILENAME}"
docker exec "${CONTAINER_NAME}" rm -f "${VEST_BACKUP_CONTAINER_TEMP_PATH}"

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
    "find '${REMOTE_PATH}' -name '${VEST_BACKUP_FILENAME_PREFIX}_*.db.gz' -mtime +${RETENTION_DAYS} -delete"

log "Backup finished successfully: ${BACKUP_FILENAME}.gz"
