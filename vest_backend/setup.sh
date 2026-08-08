#!/usr/bin/env bash
set -euo pipefail

# ── Vest Backend – Host Setup & Deployment Script ────────────────────────────
# Tested on: Debian 12 / Ubuntu 22.04+ / macOS
# Run as root or with sudo: sudo ./setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"

log()  { echo -e "\n\033[1;32m[SETUP]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\n\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ── Pre-flight root / sudo check ────────────────────────────────────────────
[[ $EUID -eq 0 ]] || err "This script must be run as root (or with sudo):\n    sudo ./setup.sh"

prompt_env_var() {
    local key="$1"
    local prompt="$2"
    local default="${3:-}"
    local value=""
    if [[ -n "${default}" ]]; then
        read -r -p "${prompt} [${default}]: " value
        value="${value:-${default}}"
    else
        read -r -p "${prompt}: " value
    fi
    # Quote values so spaces (e.g., cron) are safe when sourcing .env
    printf '%s=%q\n' "${key}" "${value}"
}

ensure_env_file() {
    if [[ -f "${ENV_FILE}" ]]; then
        read -r -p ".env already exists. Use it? [Y/n] " use_existing
        case "${use_existing}" in
            n|N)
                warn "Will re-create ${ENV_FILE} from prompts."
                ;;
            *)
                return 0
                ;;
        esac
    fi

    [[ -f "${ENV_EXAMPLE}" ]] || err "Missing ${ENV_EXAMPLE}. Cannot generate .env."

    local cron_user="${SUDO_USER:-root}"
    local cron_user_home
    cron_user_home="$(getent passwd "${cron_user}" | cut -d: -f6)"
    local default_deploy_dir="${cron_user_home}/vest-deploy"
    local default_tmp_dir="${default_deploy_dir}/tmp"

    log "Creating ${ENV_FILE} from prompts..."
    {
        prompt_env_var "VEST_DEPLOY_DIR" "Deploy directory" "${default_deploy_dir}"
        prompt_env_var "VEST_BACKUP_CRON_SCHEDULE" "Backup cron schedule (min hour dom mon dow)" "30 1 * * *"
        prompt_env_var "VEST_BACKUP_REMOTE_HOST" "Backup remote host" ""
        prompt_env_var "VEST_BACKUP_REMOTE_USER" "Backup remote user" "backup-user"
        prompt_env_var "VEST_BACKUP_REMOTE_PATH" "Backup remote path" "/srv/backups/vest"
        prompt_env_var "VEST_BACKUP_TMP_DIR" "Backup temp dir" "${default_tmp_dir}"
        prompt_env_var "VEST_BACKUP_CONTAINER_NAME" "Docker container name" "vest-deploy-api-1"
        prompt_env_var "VEST_DB_CONTAINER_PATH" "DB path in container" "/app/data/vest.db"
        prompt_env_var "VEST_BACKUP_RETENTION_DAYS" "Backup retention days" "14"
        prompt_env_var "VEST_BACKUP_LOG" "Backup log file" "/var/log/vest_backup.log"
        prompt_env_var "VEST_API_HEALTH_URL" "API health URL" "http://localhost:8002/portal/status"
        prompt_env_var "VEST_BACKUP_SSH_OPTS" "SSH opts for backup" "-o StrictHostKeyChecking=accept-new"
        prompt_env_var "VEST_BACKUP_CONTAINER_TEMP_PATH" "Temp path in container" "/tmp/vest_backup.db"
        prompt_env_var "VEST_BACKUP_FILENAME_PREFIX" "Backup filename prefix" "vest"
    } > "${ENV_FILE}"

    chmod 600 "${ENV_FILE}"
}

ensure_env_file
set -a
# shellcheck source=/dev/null
. "${ENV_FILE}"
set +a

: "${VEST_DEPLOY_DIR:?Set VEST_DEPLOY_DIR in .env}"
: "${VEST_BACKUP_CRON_SCHEDULE:?Set VEST_BACKUP_CRON_SCHEDULE in .env}"
: "${VEST_BACKUP_REMOTE_HOST:?Set VEST_BACKUP_REMOTE_HOST in .env}"
: "${VEST_BACKUP_REMOTE_USER:?Set VEST_BACKUP_REMOTE_USER in .env}"
: "${VEST_BACKUP_REMOTE_PATH:?Set VEST_BACKUP_REMOTE_PATH in .env}"
: "${VEST_BACKUP_TMP_DIR:?Set VEST_BACKUP_TMP_DIR in .env}"
: "${VEST_BACKUP_CONTAINER_NAME:?Set VEST_BACKUP_CONTAINER_NAME in .env}"
: "${VEST_DB_CONTAINER_PATH:?Set VEST_DB_CONTAINER_PATH in .env}"
: "${VEST_BACKUP_RETENTION_DAYS:?Set VEST_BACKUP_RETENTION_DAYS in .env}"
: "${VEST_BACKUP_LOG:?Set VEST_BACKUP_LOG in .env}"
: "${VEST_API_HEALTH_URL:?Set VEST_API_HEALTH_URL in .env}"

CRON_USER="${SUDO_USER:-root}"
CRON_USER_HOME="$(getent passwd "${CRON_USER}" | cut -d: -f6)"
DEPLOY_DIR="${VEST_DEPLOY_DIR}"

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
rm -rf "${DEPLOY_DIR}/parsers" "${DEPLOY_DIR}/templates"
cp "${SCRIPT_DIR}/app.py"             "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/requirements.txt"   "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/Dockerfile"         "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/docker-compose.yml" "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/.dockerignore"      "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/backup.sh"          "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/.env"               "${DEPLOY_DIR}/"
cp "${SCRIPT_DIR}/config.json"        "${DEPLOY_DIR}/"
cp -r "${SCRIPT_DIR}/parsers"         "${DEPLOY_DIR}/"
cp -r "${SCRIPT_DIR}/templates"       "${DEPLOY_DIR}/"

chmod +x "${DEPLOY_DIR}/backup.sh"
chown "${CRON_USER}":"${CRON_USER}" "${DEPLOY_DIR}/.env"
chmod 600 "${DEPLOY_DIR}/.env"

log "Verifying deployment files..."
for f in app.py requirements.txt Dockerfile docker-compose.yml .dockerignore backup.sh .env config.json parsers templates; do
    [[ -e "${DEPLOY_DIR}/${f}" ]] || err "Missing ${DEPLOY_DIR}/${f} — copy failed."
done
log "All files deployed to ${DEPLOY_DIR}:"
ls -la "${DEPLOY_DIR}/"

# ── 4. Verify SSH connectivity to backup host ────────────────────────────────
# When running under sudo, use the invoking user's SSH key
log "Checking SSH connectivity to ${VEST_BACKUP_REMOTE_USER}@${VEST_BACKUP_REMOTE_HOST} (using ${CRON_USER_HOME}/.ssh)..."
if sudo -u "${CRON_USER}" ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "${VEST_BACKUP_REMOTE_USER}@${VEST_BACKUP_REMOTE_HOST}" "echo ok" &>/dev/null; then
    log "SSH connection to backup host verified."
else
    warn "Cannot connect to ${VEST_BACKUP_REMOTE_USER}@${VEST_BACKUP_REMOTE_HOST} via SSH."
    warn "Make sure your key (${CRON_USER_HOME}/.ssh/id_*) is authorized on the remote host."
fi

# ── 5. Build & start containers ─────────────────────────────────────────────
log "Building and starting containers..."
docker compose -f "${DEPLOY_DIR}/docker-compose.yml" --project-directory "${DEPLOY_DIR}" up --build -d

log "Waiting for API to become healthy..."
for i in $(seq 1 15); do
    if curl -sf "${VEST_API_HEALTH_URL}" >/dev/null 2>&1; then
        log "API is up and responding."
        break
    fi
    if [[ $i -eq 15 ]]; then
        warn "API did not respond after 15 seconds. Check logs with: docker compose --project-directory ${DEPLOY_DIR} logs"
    fi
    sleep 1
done

# ── 6. Configure cron job for backups ────────────────────────────────────────
# Run backup as the invoking user so their ~/.ssh key is used
CRON_CMD="BACKUP_ENV_FILE=${DEPLOY_DIR}/.env ${DEPLOY_DIR}/backup.sh >> ${VEST_BACKUP_LOG} 2>&1"

# Add cron entry only if it doesn't already exist (in the invoking user's crontab)
if crontab -u "${CRON_USER}" -l 2>/dev/null | grep -qF "${DEPLOY_DIR}/backup.sh"; then
    log "Backup cron job already exists for ${CRON_USER}."
else
    log "Installing cron job for ${CRON_USER}: ${VEST_BACKUP_CRON_SCHEDULE}"
    (crontab -u "${CRON_USER}" -l 2>/dev/null || true; echo "${VEST_BACKUP_CRON_SCHEDULE} ${CRON_CMD}") | crontab -u "${CRON_USER}" -
fi

# Verify cron entry exists
if crontab -u "${CRON_USER}" -l 2>/dev/null | grep -qF "${DEPLOY_DIR}/backup.sh"; then
    log "Verified backup cron job is scheduled for ${CRON_USER}."
else
    warn "Backup cron job was not found for ${CRON_USER}. Please check crontab -u ${CRON_USER} -l"
fi

# Check if a backup is currently running
if pgrep -f "${DEPLOY_DIR}/backup.sh" >/dev/null 2>&1; then
    warn "A backup appears to be running now (${DEPLOY_DIR}/backup.sh)."
else
    log "No backup process detected (expected unless running at scheduled time)."
fi

# ── 8. Run an initial backup to validate setup ──────────────────────────────
log "Running initial backup to validate configuration..."
mkdir -p "${VEST_BACKUP_TMP_DIR}"
chown "${CRON_USER}":"${CRON_USER}" "${VEST_BACKUP_TMP_DIR}"
chmod 700 "${VEST_BACKUP_TMP_DIR}"
if sudo -u "${CRON_USER}" BACKUP_ENV_FILE="${DEPLOY_DIR}/.env" "${DEPLOY_DIR}/backup.sh"; then
    log "Initial backup completed successfully."
else
    warn "Initial backup failed. Check ${VEST_BACKUP_LOG} and remote connectivity."
fi

# ── 7. Create logrotate config for backup log ───────────────────────────────
cat > /etc/logrotate.d/vest_backup <<LOGROTATE
${VEST_BACKUP_LOG} {
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
echo "  Application:  http://<this-host>:8002"
echo "  API docs:     http://<this-host>:8002/docs"
echo "  Logs:         docker compose --project-directory ${DEPLOY_DIR} logs -f"
echo "  Backup log:   ${VEST_BACKUP_LOG}"
echo "  Backup cron:  ${VEST_BACKUP_CRON_SCHEDULE}"
echo ""
echo "  To run a backup manually:"
echo "    ${DEPLOY_DIR}/backup.sh"
echo ""
