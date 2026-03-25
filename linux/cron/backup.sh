#!/bin/bash
################################################################################
# backup.sh - Backup directory with timestamp
#
# EXECUTION:
#   chmod +x backup.sh
#   ./backup.sh /path/to/source
#   ./backup.sh /path/to/source /path/to/backup
#
# DESCRIPTION:
#   Creates a timestamped backup of a directory to /backup/ (or custom path).
#   Suitable for cron execution (minimal output, suitable for quiet operation).
#   Logs backup completion to syslog.
#
# REQUIREMENTS:
#   - tar command
#   - Destination directory must be writable
#   - Source directory must be readable
#
# AUTHOR:
#   Aniruddha Jadhav
#
# DATE:
#   2025-03-25
#
################################################################################

set -euo pipefail

# Global configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_BACKUP_DIR="/backup"
readonly TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

################################################################################
# UTILITY FUNCTIONS
################################################################################

# ============================================================================
# log_to_syslog()
# Log message to syslog (suitable for cron)
# Args: message (string)
# ============================================================================
log_to_syslog() {
	logger -t "$SCRIPT_NAME" "$1"
}

# ============================================================================
# error_exit()
# Log error and exit
# Args: message (string)
# ============================================================================
error_exit() {
	log_to_syslog "ERROR: $1"
	echo "ERROR: $1" >&2
	exit 1
}

# ============================================================================
# validate_directory()
# Check if directory exists and is readable
# Args: directory (string)
# Returns: 0 if valid, 1 if invalid
# ============================================================================
validate_directory() {
	local dir="$1"
	
	if [[ ! -d "$dir" ]]; then
		return 1
	fi
	
	if [[ ! -r "$dir" ]]; then
		return 1
	fi
	
	return 0
}

################################################################################
# BACKUP FUNCTION
################################################################################

# ============================================================================
# perform_backup()
# Create timestamped backup of source directory
# Args: source_dir (string), backup_base_dir (string)
# ============================================================================
perform_backup() {
	local source_dir="$1"
	local backup_base_dir="${2:-$DEFAULT_BACKUP_DIR}"
	local source_basename
	local backup_file
	local backup_size
	
	# Create backup directory if it doesn't exist
	if [[ ! -d "$backup_base_dir" ]]; then
		mkdir -p "$backup_base_dir" || error_exit "Cannot create backup directory: $backup_base_dir"
	fi
	
	# Check backup directory is writable
	if [[ ! -w "$backup_base_dir" ]]; then
		error_exit "Backup directory not writable: $backup_base_dir"
	fi
	
	# Get source directory name
	source_basename=$(basename "$source_dir")
	
	# Create backup filename with timestamp
	backup_file="${backup_base_dir}/${source_basename}_${TIMESTAMP}.tar.gz"
	
	# Perform backup
	log_to_syslog "Starting backup of $source_dir to $backup_file"
	
	if tar -czf "$backup_file" -C "$(dirname "$source_dir")" "$source_basename" 2>/dev/null; then
		backup_size=$(du -h "$backup_file" | cut -f1)
		log_to_syslog "SUCCESS: Backup created: $backup_file (size: $backup_size)"
		echo "Backup created: $backup_file ($backup_size)"
		return 0
	else
		error_exit "Failed to create backup of $source_dir"
	fi
}

################################################################################
# MAIN
################################################################################

main() {
	# Validate arguments
	if [[ $# -eq 0 ]]; then
		error_exit "Usage: $SCRIPT_NAME <source_directory> [backup_directory]"
	fi
	
	local source_dir="$1"
	local backup_dir="${2:-$DEFAULT_BACKUP_DIR}"
	
	# Validate source directory
	if ! validate_directory "$source_dir"; then
		error_exit "Source directory not found or not readable: $source_dir"
	fi
	
	# Perform backup
	perform_backup "$source_dir" "$backup_dir"
}

# Execute main function
main "$@"

################################################################################
# CRONTAB EXAMPLES
################################################################################
#
# # Backup /home/user every day at 2 AM
# 0 2 * * * /home/user/scripts/backup.sh /home/user /backup >/dev/null 2>&1
#
# # Backup /var/www every Sunday at 3 AM
# 0 3 * * 0 /home/user/scripts/backup.sh /var/www /backup >/dev/null 2>&1
#
# # Backup /etc every day at 4 AM
# 0 4 * * * /home/user/scripts/backup.sh /etc /backup >/dev/null 2>&1
#
# # Backup database every 6 hours
# 0 */6 * * * /home/user/scripts/backup.sh /var/lib/mysql /backup/databases >/dev/null 2>&1
#
# NOTES:
# - Output redirected to /dev/null (logging via syslog)
# - Monitor with: tail -f /var/log/syslog | grep backup.sh
# - Or: journalctl -u cron -f
#
################################################################################
