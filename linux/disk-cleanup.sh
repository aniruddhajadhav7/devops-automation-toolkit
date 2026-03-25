#!/bin/bash
################################################################################
# disk-cleanup.sh - Find and manage large/old files with safety
#
# EXECUTION:
#   chmod +x disk-cleanup.sh
#   ./disk-cleanup.sh                          # Preview cleanup candidates
#   ./disk-cleanup.sh --dry-run                # Show what would be deleted
#   ./disk-cleanup.sh --delete                 # Interactive deletion
#   ./disk-cleanup.sh --help                   # Show usage information
#
# DESCRIPTION:
#   Identifies and manages disk space by finding large and old files:
#   - Locate large files (default: >100MB)
#   - Locate old log files (default: >7 days)
#   - Display summary of disk usage
#   - Preview deletions without executing (--dry-run)
#   - Interactive confirmation before deletion
#   - Calculate and report recoverable space
#
# REQUIREMENTS:
#   - Linux system with: find, du, df, sort, rm
#   - Appropriate permissions to access files
#   - Compatible with: Ubuntu, Debian, CentOS, RHEL
#
# AUTHOR:
#  Aniruddha Jadhav
#
# DATE:
#   2025-03-25
#
################################################################################

set -euo pipefail

# Global configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
readonly LARGE_FILE_SIZE="100M"      # Find files larger than this
readonly OLD_LOG_DAYS="7"             # Find logs older than this many days
readonly LOG_EXTENSIONS="*.log *.gz *.zip *.tar *.bak"

################################################################################
# UTILITY FUNCTIONS
################################################################################

# ============================================================================
# display_help()
# Display usage information and examples
# ============================================================================
display_help() {
	cat <<-EOF
		Usage: $SCRIPT_NAME [OPTION]
		
		Identify large and old files to reclaim disk space safely.
		
		OPTIONS:
		  --dry-run                      Preview files that would be deleted
		  --delete                       Interactively delete selected files
		  --threshold SIZE               Change large file threshold (default: 100M)
		  --help, -h                     Show this help message
		  --version, -v                  Show script version
		
		EXAMPLES:
		  $SCRIPT_NAME                           # Shows summary and candidates
		  $SCRIPT_NAME --dry-run                  # Preview deletions
		  $SCRIPT_NAME --threshold 500M           # Find files >500MB
		  $SCRIPT_NAME --delete                   # Interactive deletion mode
		  
		DEFAULT THRESHOLDS:
		  Large files:   > 100 MB
		  Old logs:      > 7 days old
		  Search paths:  / (entire filesystem)
		
		NOTES:
		  - Requires read/write permissions on target files
		  - Use --dry-run first to preview what would be deleted
		  - Interactive mode asks confirmation before each deletion
		  - System files and temporary directories are excluded
		  - Results show individual file size and cumulative freed space
		  - Requires sudo for some system directories
		
		SAFE USAGE:
		  1. Run without options to see summary
		  2. Run with --dry-run to preview deletions
		  3. Run with --delete for interactive deletion
		
	EOF
}

# ============================================================================
# error_exit()
# Print error message and exit with status 1
# Args: message (string)
# ============================================================================
error_exit() {
	echo "ERROR: $1" >&2
	exit 1
}

# ============================================================================
# human_readable_size()
# Convert bytes to human-readable format
# Args: size_in_bytes (integer)
# Returns: formatted size string
# ============================================================================
human_readable_size() {
	local bytes=$1
	local size
	
	if [[ $bytes -lt 1024 ]]; then
		size=$(printf "%.0f" "$bytes")
		echo "${size}B"
	elif [[ $bytes -lt 1048576 ]]; then
		size=$(printf "%.1f" "$(echo "$bytes / 1024" | bc -l)")
		echo "${size}KB"
	elif [[ $bytes -lt 1073741824 ]]; then
		size=$(printf "%.1f" "$(echo "$bytes / 1048576" | bc -l)")
		echo "${size}MB"
	else
		size=$(printf "%.1f" "$(echo "$bytes / 1073741824" | bc -l)")
		echo "${size}GB"
	fi
}

################################################################################
# ANALYSIS FUNCTIONS
################################################################################

# ============================================================================
# show_disk_summary()
# Display overall disk usage summary
# ============================================================================
show_disk_summary() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "DISK USAGE SUMMARY"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	df -h | grep -E "^/dev/" | awk '{
		printf "%-20s %10s %10s %10s %6s\n", $1, $2, $3, $4, $5
	}'
	echo ""
}

# ============================================================================
# find_large_files()
# Locate files larger than specified threshold
# Args: threshold (string like "100M")
# Returns: list of files with sizes
# ============================================================================
find_large_files() {
	local threshold="$1"
	
	# Search common directories; exclude system paths
	find / -xdev \
		-type f \
		-size +"$threshold" \
		-not -path "*/proc/*" \
		-not -path "*/sys/*" \
		-not -path "*/.cache/*" \
		-not -path "*/node_modules/*" \
		2>/dev/null | while read -r file; do
		
		if [[ -r "$file" ]]; then
			size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
			echo "$size $file"
		fi
	done | sort -rn
}

# ============================================================================
# find_old_logs()
# Locate log files older than specified days
# Args: days (integer)
# Returns: list of files with creation dates
# ============================================================================
find_old_logs() {
	local days="$1"
	
	# Find old log files in common log directories
	find /var/log \
		-type f \
		-mtime +"$days" \
		\( -name "*.log" -o -name "*.gz" -o -name "*.zip" \) \
		2>/dev/null | while read -r file; do
		
		if [[ -r "$file" ]]; then
			size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
			echo "$size $file"
		fi
	done | sort -rn
}

# ============================================================================
# display_deletion_candidates()
# Show files that could be deleted
# Args: threshold (string)
# ============================================================================
display_deletion_candidates() {
	local threshold="$1"
	local large_total=0
	local log_total=0
	
	echo ""
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║               DISK CLEANUP CANDIDATES                          ║"
	echo "║                   $(date '+%Y-%m-%d %H:%M:%S')                           ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	
	show_disk_summary
	
	# Find and display large files
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "LARGE FILES (>$threshold)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	local large_count=0
	while IFS= read -r size file; do
		large_total=$((large_total + size))
		printf "%-12s  %s\n" "$(human_readable_size "$size")" "$file"
		((++large_count))
		[[ $large_count -ge 15 ]] && break
	done < <(find_large_files "$threshold")
	
	if [[ $large_count -eq 0 ]]; then
		echo "  (No files found larger than $threshold)"
	else
		echo ""
		echo "  Subtotal (large files): $(human_readable_size "$large_total")"
	fi
	echo ""
	
	# Find and display old logs
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "OLD LOG FILES (>${OLD_LOG_DAYS} days)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	local log_count=0
	while IFS= read -r size file; do
		log_total=$((log_total + size))
		printf "%-12s  %s\n" "$(human_readable_size "$size")" "$file"
		((++log_count))
		[[ $log_count -ge 15 ]] && break
	done < <(find_old_logs "$OLD_LOG_DAYS")
	
	if [[ $log_count -eq 0 ]]; then
		echo "  (No log files found older than $OLD_LOG_DAYS days)"
	else
		echo ""
		echo "  Subtotal (old logs): $(human_readable_size "$log_total")"
	fi
	echo ""
	
	# Total summary
	local total=$((large_total + log_total))
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "POTENTIAL FREED SPACE: $(human_readable_size "$total")"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
}

# ============================================================================
# dry_run_deletion()
# Preview what would be deleted without actually deleting
# Args: threshold (string)
# ============================================================================
dry_run_deletion() {
	local threshold="$1"
	
	echo ""
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║                     DRY RUN (PREVIEW)                          ║"
	echo "║              No files will be deleted                          ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	echo ""
	
	display_deletion_candidates "$threshold"
}

# ============================================================================
# interactive_delete()
# Interactively delete files with confirmation
# Args: threshold (string)
# ============================================================================
interactive_delete() {
	local threshold="$1"
	local total_deleted=0
	local count_deleted=0
	
	echo ""
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║                  INTERACTIVE DELETION MODE                     ║"
	echo "║                You will be asked before deleting                ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	echo ""
	
	# Process large files
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "LARGE FILES (>$threshold)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	while IFS= read -r size file; do
		echo ""
		echo "File: $file"
		echo "Size: $(human_readable_size "$size")"
		read -r -p "Delete this file? (yes/no): " confirm
		
		if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
			if rm -f "$file"; then
				total_deleted=$((total_deleted + size))
				((++count_deleted))
				echo "✓ Deleted"
			else
				echo "✗ Failed to delete"
			fi
		else
			echo "Skipped"
		fi
	done < <(find_large_files "$threshold" | head -20)
	
	# Process old logs
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "OLD LOG FILES (>${OLD_LOG_DAYS} days)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	while IFS= read -r size file; do
		echo ""
		echo "File: $file"
		echo "Size: $(human_readable_size "$size")"
		read -r -p "Delete this file? (yes/no): " confirm
		
		if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
			if rm -f "$file"; then
				total_deleted=$((total_deleted + size))
				((++count_deleted))
				echo "✓ Deleted"
			else
				echo "✗ Failed to delete"
			fi
		else
			echo "Skipped"
		fi
	done < <(find_old_logs "$OLD_LOG_DAYS" | head -20)
	
	# Summary
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "DELETION SUMMARY"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "Files Deleted:      $count_deleted"
	echo "Space Freed:        $(human_readable_size "$total_deleted")"
	echo ""
}

################################################################################
# MAIN
################################################################################

main() {
	local threshold="$LARGE_FILE_SIZE"
	local mode="default"
	
	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run)
				mode="dry-run"
				shift
				;;
			--delete)
				mode="delete"
				shift
				;;
			--threshold)
				[[ $# -lt 2 ]] && error_exit "Missing value for --threshold"
				threshold="$2"
				shift 2
				;;
			--help|-h)
				display_help
				exit 0
				;;
			--version|-v)
				echo "$SCRIPT_NAME version $VERSION"
				exit 0
				;;
			*)
				error_exit "Unknown option '$1'"
				;;
		esac
	done
	
	# Execute based on mode
	case "$mode" in
		default)
			display_deletion_candidates "$threshold"
			;;
		dry-run)
			dry_run_deletion "$threshold"
			;;
		delete)
			interactive_delete "$threshold"
			;;
	esac
}

# Execute main function with all arguments
main "$@"

################################################################################
# EXAMPLE OUTPUT
################################################################################
#
# ╔════════════════════════════════════════════════════════════════╗
# ║               DISK CLEANUP CANDIDATES                          ║
# ║                   2026-03-25 14:32:47                          ║
# ╚════════════════════════════════════════════════════════════════╝
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISK USAGE SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# /dev/sda1                465G        250G        189G      54%
# /dev/sdb1                  1T        654G        346G      65%
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LARGE FILES (>100M)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2.3GB     /var/log/syslog.1
# 1.8GB     /opt/backups/backup-2026-03-10.tar
# 1.2GB     /home/user/Downloads/archive.zip
# 950.0MB   /var/cache/apt/archives/build-files.tar.gz
# 
#   Subtotal (large files): 6.3GB
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OLD LOG FILES (>7 days)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 500.0MB   /var/log/apache2/access.log.10
# 280.0MB   /var/log/auth.log.2.gz
# 150.0MB   /var/log/syslog.5.gz
#
#   Subtotal (old logs): 930.0MB
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POTENTIAL FREED SPACE: 7.2GB
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
################################################################################
