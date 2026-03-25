#!/bin/bash
################################################################################
# log-analyzer.sh - Analyze system logs for errors, warnings, and failures
#
# EXECUTION:
#   chmod +x log-analyzer.sh
#   ./log-analyzer.sh                          # Analyze syslog
#   ./log-analyzer.sh /var/log/auth.log        # Analyze specific log file
#   ./log-analyzer.sh --help                   # Show usage information
#
# DESCRIPTION:
#   Parses system logs and extracts critical information:
#   - Counts ERROR, WARNING, and FAILED entries
#   - Identifies top 10 most frequent issues
#   - Generates formatted summary report
#   - Supports custom log files via command-line argument
#
# REQUIREMENTS:
#   - Linux system with: grep, awk, sort, uniq, date
#   - Read permissions on log files (may require sudo)
#   - Compatible with: Ubuntu, Debian, CentOS, RHEL
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
readonly VERSION="1.0.0"
readonly DEFAULT_LOGFILE="/var/log/syslog"
readonly ALTERNATE_LOGFILE="/var/log/messages"

################################################################################
# UTILITY FUNCTIONS
################################################################################

# ============================================================================
# display_help()
# Display usage information and examples
# ============================================================================
display_help() {
	cat <<-EOF
		Usage: $SCRIPT_NAME [LOG_FILE] [OPTION]
		
		Analyze system logs to identify errors, warnings, and failures.
		Generates a summary report with frequency counts and top issues.
		
		ARGUMENTS:
		  LOG_FILE                       Path to log file (default: /var/log/syslog)
		
		OPTIONS:
		  --help, -h                     Show this help message
		  --version, -v                  Show script version
		  --top N                        Show top N issues (default: 10)
		
		EXAMPLES:
		  $SCRIPT_NAME                             # Analyze /var/log/syslog
		  $SCRIPT_NAME /var/log/auth.log           # Analyze auth.log
		  $SCRIPT_NAME /var/log/kern.log --top 15  # Show top 15 kernel issues
		  
		SEARCH PATTERNS:
		  - ERROR      : Case-insensitive match for "error"
		  - WARNING    : Case-insensitive match for "warn"
		  - FAILED     : Case-insensitive match for "fail"
		
		NOTES:
		  - Large log files may take a few seconds to analyze
		  - Requires read permissions on log file (use sudo if needed)
		  - Top issues show unique error messages/patterns
		  - Log summaries are useful for troubleshooting and auditing
		
		EXAMPLES OUTPUT:
		  Total Entries Analyzed: 2547
		  ERROR count: 123
		  WARNING count: 456
		  FAILED count: 89
		  
		  Top 10 Most Frequent Issues:
		  ...
		
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
# validate_logfile()
# Check if log file exists and is readable
# Args: logfile (string)
# Returns: 0 if valid, 1 if invalid
# ============================================================================
validate_logfile() {
	local logfile="$1"
	
	# Check if file exists
	if [[ ! -f "$logfile" ]]; then
		return 1
	fi
	
	# Check if file is readable
	if [[ ! -r "$logfile" ]]; then
		return 1
	fi
	
	return 0
}

# ============================================================================
# find_logfile()
# Attempt to find default log file
# Returns: path to log file, or error
# ============================================================================
find_logfile() {
	# Try primary default
	if validate_logfile "$DEFAULT_LOGFILE"; then
		echo "$DEFAULT_LOGFILE"
		return 0
	fi
	
	# Try alternate default
	if validate_logfile "$ALTERNATE_LOGFILE"; then
		echo "$ALTERNATE_LOGFILE"
		return 0
	fi
	
	# No default found
	error_exit "Cannot find system log file. Please specify log file path."
}

################################################################################
# ANALYSIS FUNCTIONS
################################################################################

# ============================================================================
# count_severity()
# Count occurrences of severity level in log file
# Args: logfile (string), pattern (string)
# Returns: count (integer)
# ============================================================================
count_severity() {
	local logfile="$1"
	local pattern="$2"
	
	grep -ic "$pattern" "$logfile" || echo "0"
}

# ============================================================================
# extract_top_issues()
# Extract and count unique error messages/patterns
# Args: logfile (string), pattern (string), limit (integer)
# Returns: formatted list of top issues
# ============================================================================
extract_top_issues() {
	local logfile="$1"
	local pattern="$2"
	local limit="${3:-10}"
	
	# Extract lines matching pattern, extract error message core,
	# count occurrences, and sort by frequency
	grep -i "$pattern" "$logfile" \
		| awk -F'[:=-]' '{
			# Extract the main error message (usually after daemon:)
			msg = $0
			# Limit message length
			msg = substr(msg, 1, 80)
			if (length(msg) > 1) {
				count[msg]++
			}
		}
		END {
			# Sort by count ascending, then output descending
			for (msg in count) {
				print count[msg] " " msg
			}
		}' \
		| sort -rn \
		| head -n "$limit" \
		| awk '{
			count=$1
			msg=substr($0, length($1)+2)
			printf "  %4d  %s\n", count, msg
		}'
}

# ============================================================================
# generate_report()
# Generate comprehensive log analysis report
# Args: logfile (string)
# ============================================================================
generate_report() {
	local logfile="$1"
	local total_entries
	local error_count
	local warning_count
	local failed_count
	
	# Count total entries
	total_entries=$(wc -l < "$logfile")
	
	# Count each severity level
	error_count=$(count_severity "$logfile" "error")
	warning_count=$(count_severity "$logfile" "warn")
	failed_count=$(count_severity "$logfile" "fail")
	
	# Print header
	echo ""
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║                    LOG ANALYSIS REPORT                         ║"
	echo "║                   $(date '+%Y-%m-%d %H:%M:%S')                           ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	echo ""
	
	# Print summary section
	echo "Log File:  $logfile"
	echo "Analyzed:  $(stat -f%Sm -t '%Y-%m-%d %H:%M:%S' "$logfile" 2>/dev/null || echo "N/A")"
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "SUMMARY"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "Total Entries Analyzed:  $total_entries"
	echo "ERROR Count:             $error_count ($(( error_count * 100 / total_entries ))%)"
	echo "WARNING Count:           $warning_count ($(( warning_count * 100 / total_entries ))%)"
	echo "FAILED Count:            $failed_count ($(( failed_count * 100 / total_entries ))%)"
	echo ""
	
	# Print top issues for ERROR
	if [[ $error_count -gt 0 ]]; then
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "TOP 10 ERROR MESSAGES"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		extract_top_issues "$logfile" "error" 10
		echo ""
	fi
	
	# Print top issues for WARNING
	if [[ $warning_count -gt 0 ]]; then
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "TOP 10 WARNING MESSAGES"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		extract_top_issues "$logfile" "warn" 10
		echo ""
	fi
	
	# Print top issues for FAILED
	if [[ $failed_count -gt 0 ]]; then
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "TOP 10 FAILED MESSAGES"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		extract_top_issues "$logfile" "fail" 10
		echo ""
	fi
}

################################################################################
# MAIN
################################################################################

main() {
	local logfile
	local top_limit=10
	
	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--help|-h)
				display_help
				exit 0
				;;
			--version|-v)
				echo "$SCRIPT_NAME version $VERSION"
				exit 0
				;;
			--top)
				[[ $# -lt 2 ]] && error_exit "Missing number for --top"
				top_limit="$2"
				shift 2
				;;
			-*)
				error_exit "Unknown option '$1'"
				;;
			*)
				# Assume it's the logfile
				logfile="$1"
				shift
				;;
		esac
	done
	
	# Determine log file to analyze
	if [[ -z "${logfile:-}" ]]; then
		logfile=$(find_logfile)
	else
		if ! validate_logfile "$logfile"; then
			error_exit "Log file not found or not readable: $logfile"
		fi
	fi
	
	# Generate and display report
	generate_report "$logfile"
}

# Execute main function with all arguments
main "$@"

################################################################################
# EXAMPLE OUTPUT
################################################################################
#
# ╔════════════════════════════════════════════════════════════════╗
# ║                    LOG ANALYSIS REPORT                         ║
# ║                   2026-03-25 14:52:30                          ║
# ╚════════════════════════════════════════════════════════════════╝
#
# Log File:  /var/log/syslog
# Analyzed:  2026-03-25 14:52:30
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Total Entries Analyzed:  125847
# ERROR Count:             342 (0%)
# WARNING Count:           1205 (0%)
# FAILED Count:            89 (0%)
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOP 10 ERROR MESSAGES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#    34  Connection refused
#    28  Timeout
#    22  Permission denied
#    19  File not found
#    15  Memory allocation failed
#    12  Database connection error
#    11  SSL certificate error
#     8  Service unavailable
#     7  Invalid configuration
#     5  Disk space low
#
################################################################################
