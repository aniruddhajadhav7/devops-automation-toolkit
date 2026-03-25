#!/bin/bash
################################################################################
# log-rotate.sh - Archive and compress old logs
#
# EXECUTION:
#   chmod +x log-rotate.sh
#   ./log-rotate.sh                         # Archive logs >7 days old
#   ./log-rotate.sh 14                      # Archive logs >14 days old
#
# DESCRIPTION:
#   Finds log files in /var/log older than specified days,
#   archives them to /var/log/archive/, and compresses with gzip.
#   Minimal output (suitable for cron execution).
#   Logs actions to syslog.
#
# REQUIREMENTS:
#   - tar, gzip, find commands
#   - Write permissions to /var/log/archive
#   - Read permissions on log files
#
# AUTHOR:
#  Aniruddha Jadhav
#
# DATE:
#   2025-08-07
#
################################################################################

set -euo pipefail

# Global configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/var/log"
readonly ARCHIVE_DIR="/var/log/archive"
readonly DEFAULT_DAYS=7

################################################################################
# UTILITY FUNCTIONS
################################################################################

# ============================================================================
# log_to_syslog()
# Log message to syslog
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
# validate_numeric()
# Validate that input is a number
# Args: value (string)
# Returns: 0 if numeric, 1 if not
# ============================================================================
validate_numeric() {
	local value="$1"
	[[ "$value" =~ ^[0-9]+$ ]] && return 0 || return 1
}

################################################################################
# ROTATION FUNCTION
################################################################################

# ============================================================================
# rotate_logs()
# Archive and compress old log files
# Args: days (integer)
# ============================================================================
rotate_logs() {
	local days="$1"
	local archive_count=0
	local compressed_size=0
	
	# Create archive directory if it doesn't exist
	if [[ ! -d "$ARCHIVE_DIR" ]]; then
		mkdir -p "$ARCHIVE_DIR" || error_exit "Cannot create archive directory: $ARCHIVE_DIR"
	fi
	
	# Ensure archive directory is writable
	if [[ ! -w "$ARCHIVE_DIR" ]]; then
		error_exit "Archive directory not writable: $ARCHIVE_DIR"
	fi
	
	log_to_syslog "Starting log rotation (archiving logs >$days days old)"
	
	# Find and process old log files
	while IFS= read -r logfile; do
		# Skip if file no longer exists (race condition)
		[[ ! -f "$logfile" ]] && continue
		
		# Get filename without extension for archive naming
		local archive_name
		local archive_path
		local file_size
		
		archive_name=$(basename "$logfile" | sed 's/\.[^.]*$//')
		archive_path="${ARCHIVE_DIR}/${archive_name}_$(date '+%Y%m%d_%H%M%S').tar.gz"
		file_size=$(du -h "$logfile" | cut -f1)
		
		# Archive and compress
		if tar -czf "$archive_path" -C "$(dirname "$logfile")" "$(basename "$logfile")" 2>/dev/null; then
			# Remove original file
			if rm -f "$logfile" 2>/dev/null; then
				((++archive_count))
				compressed_size=$(du -h "$archive_path" | cut -f1)
				log_to_syslog "Archived: $logfile -> $archive_path ($compressed_size)"
			else
				log_to_syslog "WARNING: Could not remove original log: $logfile"
			fi
		else
			log_to_syslog "WARNING: Failed to archive $logfile"
		fi
		
	done < <(find "$LOG_DIR" -maxdepth 1 -type f -name "*.log*" -mtime +"$days" 2>/dev/null)
	
	log_to_syslog "Log rotation completed: $archive_count files archived"
}

################################################################################
# MAIN
################################################################################

main() {
	local days="${1:-$DEFAULT_DAYS}"
	
	# Validate days argument
	if ! validate_numeric "$days"; then
		error_exit "Days argument must be a number, got: $days"
	fi
	
	# Enforce minimum 1 day
	if [[ $days -lt 1 ]]; then
		error_exit "Days must be at least 1"
	fi
	
	# Perform rotation
	rotate_logs "$days"
}

# Execute main function
main "$@"

################################################################################
# CRONTAB EXAMPLES
################################################################################
#
# # Rotate logs older than 7 days daily at 1 AM
# 0 1 * * * /home/user/scripts/log-rotate.sh 7 >/dev/null 2>&1
#
# # Rotate logs older than 30 days weekly
# 0 2 * * 0 /home/user/scripts/log-rotate.sh 30 >/dev/null 2>&1
#
# # Aggressive rotation: every 3 days for 5+ day old logs
# 0 3 */3 * * /home/user/scripts/log-rotate.sh 5 >/dev/null 2>&1
#
# MONITORING:
# Watch archive directory size:
#   du -sh /var/log/archive
#
# View recent rotations:
#   tail -20 /var/log/syslog | grep log-rotate.sh
#
# Manual cleanup of old archives:
#   find /var/log/archive -type f -mtime +90 -delete
#
################################################################################
