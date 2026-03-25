#!/bin/bash
################################################################################
# health-check.sh - Server/service health check with logging
#
# EXECUTION:
#   chmod +x health-check.sh
#   ./health-check.sh
#   ./health-check.sh google.com
#   ./health-check.sh --host example.com --verbose
#
# DESCRIPTION:
#   Performs health checks on a target server/service via ping.
#   Logs results (success/failure) with timestamp to log file.
#   Minimal output by default (suitable for quiet cron execution).
#   Exit codes: 0 = success, 1 = failure
#
# REQUIREMENTS:
#   - ping command
#   - Write permissions to /var/log/health-check.log
#   - Network connectivity to target
#
# AUTHOR:
#  Aniruddha Jadhav
#
# DATE:
#   2025-07-25
#
################################################################################

set -euo pipefail

# Global configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_HOST="google.com"
readonly DEFAULT_TIMEOUT=5
readonly DEFAULT_COUNT=3
readonly LOG_FILE="/var/log/health-check.log"
readonly VERBOSE="${VERBOSE:-0}"

################################################################################
# UTILITY FUNCTIONS
################################################################################

# ============================================================================
# log_message()
# Log message with timestamp to log file
# Args: message (string)
# ============================================================================
log_message() {
	local message="$1"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	local log_entry="[$timestamp] $message"
	
	# Attempt to write to log file; fail gracefully if no permissions
	if [[ -w "$LOG_FILE" ]] || touch "$LOG_FILE" 2>/dev/null; then
		echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
	fi
	
	# Also output to syslog as backup
	logger -t "$SCRIPT_NAME" "$message"
}

# ============================================================================
# is_verbose()
# Check if verbose mode is enabled
# Returns: 0 if verbose, 1 if not
# ============================================================================
is_verbose() {
	[[ "${VERBOSE}" == "1" ]] || return 1
}

# ============================================================================
# verbose_echo()
# Echo only in verbose mode
# Args: message (string)
# ============================================================================
verbose_echo() {
	is_verbose && echo "$1" || true
}

################################################################################
# HEALTH CHECK FUNCTION
################################################################################

# ============================================================================
# perform_health_check()
# Ping target host and check response
# Args: host (string)
# Returns: 0 if reachable, 1 if not
# ============================================================================
perform_health_check() {
	local host="$1"
	local timeout="${2:-$DEFAULT_TIMEOUT}"
	local count="${3:-$DEFAULT_COUNT}"
	local response_time
	local success=0
	
	verbose_echo "Checking health of $host..."
	
	# Attempt to ping the host
	# Capture response time if available
	if response_time=$(ping -c "$count" -W "$timeout" "$host" 2>/dev/null | grep "time=" | awk '{print $7}' | head -1); then
		# Extract just the number
		response_time=$(echo "$response_time" | sed 's/time=//g' | sed 's/ ms//g')
		log_message "SUCCESS: $host is reachable (response time: ${response_time}ms)"
		verbose_echo "✓ $host is reachable (response time: ${response_time}ms)"
		return 0
	else
		log_message "FAILURE: $host is unreachable"
		verbose_echo "✗ $host is unreachable"
		return 1
	fi
}

# ============================================================================
# display_help()
# Display usage information
# ============================================================================
display_help() {
	cat <<-EOF
		Usage: $SCRIPT_NAME [OPTION] [HOST]
		
		Perform health check on a target server via ping.
		
		ARGUMENTS:
		  HOST                           Target hostname/IP (default: $DEFAULT_HOST)
		
		OPTIONS:
		  --host HOST                    Specify target host
		  --verbose                      Show detailed output
		  --help                         Show this help message
		
		EXAMPLES:
		  $SCRIPT_NAME                         # Check $DEFAULT_HOST
		  $SCRIPT_NAME example.com             # Check example.com
		  $SCRIPT_NAME --host 192.168.1.1     # Check IP address
		  $SCRIPT_NAME --verbose               # Verbose output
		
		LOGGING:
		  Results are logged to: $LOG_FILE
		  Format: [YYYY-MM-DD HH:MM:SS] STATUS: host (details)
		
		EXIT CODES:
		  0                              Host is reachable
		  1                              Host is unreachable
		
		ENVIRONMENT VARIABLES:
		  VERBOSE=1                      Enable verbose output
		  
		CRON USAGE:
		  0 */6 * * * $SCRIPT_NAME example.com >/dev/null 2>&1
		  (Check every 6 hours; output suppressed, logging to file)
		
	EOF
}

################################################################################
# MAIN
################################################################################

main() {
	local target_host="$DEFAULT_HOST"
	
	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--host)
				[[ $# -lt 2 ]] && { echo "ERROR: Missing host for --host"; exit 1; }
				target_host="$2"
				shift 2
				;;
			--verbose)
				VERBOSE=1
				shift
				;;
			--help)
				display_help
				exit 0
				;;
			-*)
				echo "ERROR: Unknown option '$1'" >&2
				exit 1
				;;
			*)
				# Positional argument: treat as host
				target_host="$1"
				shift
				;;
		esac
	done
	
	# Perform health check
	if perform_health_check "$target_host"; then
		exit 0
	else
		exit 1
	fi
}

# Execute main function
main "$@"

################################################################################
# CRONTAB EXAMPLES
################################################################################
#
# # Check google.com every 5 minutes
# */5 * * * * /home/user/scripts/health-check.sh google.com >/dev/null 2>&1
#
# # Check API endpoint every hour at the top of the hour
# 0 * * * * /home/user/scripts/health-check.sh api.example.com >/dev/null 2>&1
#
# # Check multiple services (create separate cron entries)
# 0 * * * * /home/user/scripts/health-check.sh api.example.com >/dev/null 2>&1
# 0 * * * * /home/user/scripts/health-check.sh db.example.com >/dev/null 2>&1
# 0 * * * * /home/user/scripts/health-check.sh cache.example.com >/dev/null 2>&1
#
# # Check during business hours only (8 AM - 6 PM on weekdays)
# 0 8-17 * * 1-5 /home/user/scripts/health-check.sh critical-service.local >/dev/null 2>&1
#
# # Check with verbose logging for debugging
# 0 * * * * VERBOSE=1 /home/user/scripts/health-check.sh api.internal >/dev/null 2>&1
#
# MONITORING:
# View recent checks:
#   tail -20 /var/log/health-check.log
#
# Watch live:
#   tail -f /var/log/health-check.log
#
# Count successes and failures:
#   grep SUCCESS /var/log/health-check.log | wc -l
#   grep FAILURE /var/log/health-check.log | wc -l
#
# Find when service was down:
#   grep FAILURE /var/log/health-check.log
#
# ALERT EXAMPLE (add to critical monitoring):
# Monitor log for consecutive failures:
#   awk '/FAILURE.*host/{c++} /SUCCESS/{c=0} c==3{print "ALERT"; exit}' /var/log/health-check.log
#
################################################################################
