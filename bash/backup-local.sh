#!/bin/bash

################################################################################
# backup-local.sh
# Description: Local backup script with tar+gz compression, timestamp, and
#              retention policy for automated backups
# Author: DevOps Automation Toolkit
# Usage: ./backup-local.sh [SOURCE_DIR] [BACKUP_DIR] [RETENTION_DAYS]
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
SOURCE_DIR="${1:-.}"
BACKUP_DIR="${2:-./backups}"
RETENTION_DAYS="${3:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${TIMESTAMP}.tar.gz"
LOG_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.log"

################################################################################
# Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR" "$@"
    exit 1
}

cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than ${RETENTION_DAYS} days..."
    find "$BACKUP_DIR" -maxdepth 1 -name "backup_*.tar.gz" -type f -mtime +${RETENTION_DAYS} | while read -r old_backup; do
        log "INFO" "Removing old backup: $(basename "$old_backup")"
        rm -f "$old_backup"
    done
}

################################################################################
# Main Script
################################################################################

# Validate source directory
if [[ ! -d "$SOURCE_DIR" ]]; then
    error_exit "Source directory does not exist: $SOURCE_DIR"
fi

# Create backup directory if it doesn't exist
if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    log "INFO" "Created backup directory: $BACKUP_DIR"
fi

log "INFO" "Starting backup process..."
log "INFO" "Source: $SOURCE_DIR"
log "INFO" "Destination: $BACKUP_DIR/$BACKUP_FILE"

# Create backup archive
if tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>>"$LOG_FILE"; then
    log "INFO" "Backup created successfully"
else
    error_exit "Failed to create backup archive"
fi

# Get backup file size
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
log "INFO" "Backup size: $BACKUP_SIZE"

# Cleanup old backups
cleanup_old_backups

log "INFO" "Backup process completed successfully"
echo -e "${GREEN}✓ Backup completed: ${BACKUP_FILE} (${BACKUP_SIZE})${NC}"
