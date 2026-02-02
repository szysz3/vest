#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${BACKUP_CONTAINER_NAME:-vest-deploy-api-1}"
DB_CONTAINER_PATH="/app/data/vest.db"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

read -rp "This will DELETE all data in the database. Are you sure? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

log "Removing database..."
docker exec "${CONTAINER_NAME}" rm -f "${DB_CONTAINER_PATH}"

log "Restarting container..."
docker restart "${CONTAINER_NAME}" > /dev/null

log "Waiting for API..."
for i in $(seq 1 15); do
    if curl -sf http://localhost:8002/transactions/form-options >/dev/null 2>&1; then
        log "Done. Database has been reset."
        exit 0
    fi
    sleep 1
done

log "Warning: API did not respond after 15 seconds. Check: docker logs ${CONTAINER_NAME}"
