#!/usr/bin/env bash
set -euo pipefail

# ── Vest Backend – Host Setup & Deployment Script ────────────────────────────
# Tested on: Debian 12 / Ubuntu 22.04+
# Run as root or with sudo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="/opt/vest"
BACKUP_CRON_SCHEDULE="30 1 * * *"       # 1:30 AM every day
REMOTE_HOST="192.168.0.10"
REMOTE_USER="${BACKUP_REMOTE_USER:-backup-user}"

log()  { echo -e "\n\033[1;32m[SETUP]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\n\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || err "This script must be run as root (or with sudo)."

log "Updating package index..."
apt-get update -qq

# ── 1. Install Docker ───────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    log "Docker already installed: $(docker --version)"
else
    log "Installing Docker..."
    apt-get install -y -qq ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable --now docker
    log "Docker installed: $(docker --version)"
fi

# ── 2. Install supporting tools ─────────────────────────────────────────────
log "Installing rsync, gzip, sqlite3..."
apt-get install -y -qq rsync gzip sqlite3

# ── 3. Deploy application ───────────────────────────────────────────────────
log "Deploying application to ${DEPLOY_DIR}..."
mkdir -p "${DEPLOY_DIR}"
cp "${SCRIPT_DIR}/app.py"             "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/requirements.txt"   "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/Dockerfile"         "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/docker-compose.yml" "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/.dockerignore"      "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/backup.sh"          "${DEPLOY_DIR}/"
chmod +x "${DEPLOY_DIR}/backup.sh"

# ── 4. Verify SSH connectivity to backup host ────────────────────────────────
log "Checking SSH connectivity to ${REMOTE_USER}@${REMOTE_HOST}..."
if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" "echo ok" &>/dev/null; then
    log "SSH connection to backup host verified."
else
    warn "Cannot connect to ${REMOTE_USER}@${REMOTE_HOST} via SSH."
    warn "Make sure your default key (~/.ssh/id_*) is authorized on the remote host."
fi

# ── 5. Build & start containers ─────────────────────────────────────────────
log "Building and starting containers..."
cd "${DEPLOY_DIR}"
docker compose up --build -d

log "Waiting for API to become healthy..."
for i in $(seq 1 15); do
    if curl -sf http://localhost:8000/transactions/form-options >/dev/null 2>&1; then
        log "API is up and responding."
        break
    fi
    if [[ $i -eq 15 ]]; then
        warn "API did not respond after 15 seconds. Check logs with: docker compose -f ${DEPLOY_DIR}/docker-compose.yml logs"
    fi
    sleep 1
done

# ── 6. Configure cron job for backups ────────────────────────────────────────
CRON_CMD="BACKUP_REMOTE_USER=${REMOTE_USER} ${DEPLOY_DIR}/backup.sh >> /var/log/vest_backup.log 2>&1"

# Add cron entry only if it doesn't already exist
if crontab -l 2>/dev/null | grep -qF "${DEPLOY_DIR}/backup.sh"; then
    log "Backup cron job already exists."
else
    log "Installing cron job: ${BACKUP_CRON_SCHEDULE}"
    (crontab -l 2>/dev/null || true; echo "${BACKUP_CRON_SCHEDULE} ${CRON_CMD}") | crontab -
fi

# ── 7. Create logrotate config for backup log ───────────────────────────────
cat > /etc/logrotate.d/vest_backup <<'LOGROTATE'
/var/log/vest_backup.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
}
LOGROTATE

# ── Done ─────────────────────────────────────────────────────────────────────
log "Setup complete!"
echo ""
echo "  Application:  http://<this-host>:8000"
echo "  API docs:     http://<this-host>:8000/docs"
echo "  Logs:         docker compose -f ${DEPLOY_DIR}/docker-compose.yml logs -f"
echo "  Backup log:   /var/log/vest_backup.log"
echo "  Backup cron:  ${BACKUP_CRON_SCHEDULE} (daily at 01:30)"
echo ""
echo "  To run a backup manually:"
echo "    ${DEPLOY_DIR}/backup.sh"
echo ""
