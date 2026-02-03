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

: "${VEST_BACKUP_CONTAINER_NAME:?Set VEST_BACKUP_CONTAINER_NAME in .env}"
: "${VEST_DB_CONTAINER_PATH:?Set VEST_DB_CONTAINER_PATH in .env}"
: "${VEST_API_HEALTH_URL:?Set VEST_API_HEALTH_URL in .env}"

CONTAINER_NAME="${VEST_BACKUP_CONTAINER_NAME}"
DB_CONTAINER_PATH="${VEST_DB_CONTAINER_PATH}"

read -rp "This will DELETE all data in the database. Are you sure? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

log "Removing database..."
docker exec "${CONTAINER_NAME}" rm -f "${DB_CONTAINER_PATH}"

log "Restarting container..."
docker restart "${CONTAINER_NAME}" > /dev/null

log "Waiting for API..."
for i in $(seq 1 15); do
    if curl -sf "${VEST_API_HEALTH_URL}" >/dev/null 2>&1; then
        log "Done. Database has been reset."
        exit 0
    fi
    sleep 1
done

log "Warning: API did not respond after 15 seconds. Check: docker logs ${CONTAINER_NAME}"
