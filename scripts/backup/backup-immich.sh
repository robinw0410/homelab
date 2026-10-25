#!/usr/bin/env bash
# Restic backup of the Immich library. Runs on the Proxmox host as /usr/local/bin/backup-immich.sh,
# started by systemd/backup-immich.timer. Backs up files only, no database dump.
set -euo pipefail

# Optional overrides, see .env.example
ENV_FILE="$(dirname "$0")/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

: "${BACKUP_MOUNT:=/mnt/media}"
: "${RESTIC_REPOSITORY:=/mnt/media/backup/immich}"
: "${RESTIC_PASSWORD_FILE:=/root/.restic/pw}"
: "${IMMICH_DATA:=/mnt/pve/storage/immich-data}"

mountpoint -q "$BACKUP_MOUNT" || { echo "HDD nicht gemountet"; exit 1; }
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE

restic backup "$IMMICH_DATA"
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
