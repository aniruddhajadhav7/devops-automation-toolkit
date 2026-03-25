#!/bin/bash
################################################################################
# process-monitor.sh - Monitor and manage system processes
#
# EXECUTION:
#   chmod +x process-monitor.sh
#   ./process-monitor.sh                       # Display top processes
#   ./process-monitor.sh --kill-pid 1234       # Kill process by PID
#   ./process-monitor.sh --kill-name nginx     # Kill processes by name
#   ./process-monitor.sh --help                # Show usage information
#
# DESCRIPTION:
#   Monitor system processes and provide process management capabilities:
#   - Display top 10 CPU-consuming processes
#   - Display top 10 memory-consuming processes
#   - Kill processes safely by PID with confirmation
#   - Kill all processes matching a name with confirmation
#   - Real-time monitoring with auto-refresh
#
# REQUIREMENTS:
#   - Linux system with: ps, top, kill, pgrep
#   - Appropriate permissions (may require sudo for other user processes)
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
readonly TOP_LIMIT=10

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
		
		Monitor system processes and provide safe process termination.
		
		OPTIONS:
		  --kill-pid PID                 Kill process by PID
		  --kill-name PROCESS_NAME       Kill all processes matching name
		  --monitor REFRESH_SECS         Continuous monitoring (default: 5 sec)
		  --top N                        Show top N processes (default: 10)
		  --help, -h                     Show this help message
		  --version, -v                  Show script version
		
		EXAMPLES:
		  $SCRIPT_NAME                           # Display top CPU and memory processes
		  $SCRIPT_NAME --kill-pid 1234           # Kill process with PID 1234
		  $SCRIPT_NAME --kill-name nginx         # Kill all nginx processes
		  $SCRIPT_NAME --monitor 3               # Refresh every 3 seconds
		  $SCRIPT_NAME --monitor 5 --top 15      # Monitor with 15 processes shown
		  
		DEFAULT BEHAVIOR:
		  Displays top 10 CPU and top 10 memory consuming processes.
		
		SAFETY FEATURES:
		  - Process existence verification before killing
		  - User confirmation required before any termination
		  - Shows process details before killing
		  - Graceful termination with timeout
		  - Prevents accidental system damage
		
		NOTES:
		  - May require sudo for processes owned by other users
		  - Real-time monitoring uses SIGTERM (graceful) not SIGKILL (force)
		  - Ctrl+C to exit monitoring mode
		  - Resource usage percentages are per-core on multicore systems
		
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
# validate_numeric()
# Validate that input is a number
# Args: value (string)
# Returns: 0 if numeric, 1 if not
# ============================================================================
validate_numeric() {
	local value="$1"
	[[ "$value" =~ ^[0-9]+$ ]] && return 0 || return 1
}

# ============================================================================
# get_process_info()
# Get detailed information about a specific process
# Args: pid (integer)
# Returns: formatted process information or error message
# ============================================================================
get_process_info() {
	local pid="$1"
	
	if ps -p "$pid" > /dev/null 2>&1; then
		ps -p "$pid" -o pid=,user=,cpu=,%mem=,comm= | awk '{
			printf "  PID: %s\n", $1
			printf "  User: %s\n", $2
			printf "  CPU: %s%%\n", $3
			printf "  Memory: %s%%\n", $4
			printf "  Command: %s\n", $5
		}'
		return 0
	else
		echo "  Process with PID $pid not found."
		return 1
	fi
}

################################################################################
# DISPLAY FUNCTIONS
################################################################################

# ============================================================================
# display_top_cpu_processes()
# Display top CPU-consuming processes
# Args: limit (integer, default: TOP_LIMIT)
# ============================================================================
display_top_cpu_processes() {
	local limit="${1:-$TOP_LIMIT}"
	
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "TOP $limit CPU-CONSUMING PROCESSES"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	ps aux --sort=-%cpu | head -n $((limit + 1)) | tail -n +2 | awk '{
		printf "%6s %-12s %6s %6s  %-50s\n", $2, $1, $3, $4, $11
	}'
	
	echo ""
}

# ============================================================================
# display_top_memory_processes()
# Display top memory-consuming processes
# Args: limit (integer, default: TOP_LIMIT)
# ============================================================================
display_top_memory_processes() {
	local limit="${1:-$TOP_LIMIT}"
	
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "TOP $limit MEMORY-CONSUMING PROCESSES"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	ps aux --sort=-%mem | head -n $((limit + 1)) | tail -n +2 | awk '{
		printf "%6s %-12s %6s %6s  %-50s\n", $2, $1, $3, $4, $11
	}'
	
	echo ""
}

# ============================================================================
# display_dashboard()
# Display process dashboard
# Args: limit (integer)
# ============================================================================
display_dashboard() {
	local limit="${1:-$TOP_LIMIT}"
	
	echo ""
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║                  PROCESS MONITOR DASHBOARD                    ║"
	echo "║                   $(date '+%Y-%m-%d %H:%M:%S')                           ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	echo ""
	echo "Legend: PID | User | CPU% | MEM% | Command"
	
	display_top_cpu_processes "$limit"
	display_top_memory_processes "$limit"
}

################################################################################
# MANAGEMENT FUNCTIONS
################################################################################

# ============================================================================
# kill_process_by_pid()
# Safely kill process by PID with confirmation
# Args: pid (integer)
# ============================================================================
kill_process_by_pid() {
	local pid="$1"
	local confirmation
	
	# Validate PID format
	if ! validate_numeric "$pid"; then
		error_exit "Invalid PID format: $pid"
	fi
	
	# Check if process exists
	if ! ps -p "$pid" > /dev/null 2>&1; then
		error_exit "Process with PID $pid does not exist."
	fi
	
	# Display process information
	echo ""
	echo "Process Information:"
	get_process_info "$pid"
	
	# Request confirmation
	echo ""
	read -r -p "Kill this process? (yes/no): " confirmation
	
	if [[ ! "$confirmation" =~ ^[Yy][Ee][Ss]$ ]]; then
		echo "Operation cancelled."
		return 0
	fi
	
	# Attempt to kill
	if kill -TERM "$pid" 2>/dev/null; then
		echo "✓ Process $pid signaled with SIGTERM (graceful termination)."
		
		# Wait a moment for graceful termination
		sleep 1
		
		# Check if still running
		if ps -p "$pid" > /dev/null 2>&1; then
			echo "Process still running; sending SIGKILL..."
			if kill -9 "$pid" 2>/dev/null; then
				echo "✓ Process $pid force-killed with SIGKILL."
			else
				error_exit "Failed to kill process $pid."
			fi
		fi
	else
		error_exit "Failed to signal process $pid. Check permissions."
	fi
}

# ============================================================================
# kill_process_by_name()
# Kill all processes matching a name with confirmation
# Args: process_name (string)
# ============================================================================
kill_process_by_name() {
	local process_name="$1"
	local pids=()
	local confirmation
	
	# Find matching process IDs
	while IFS= read -r pid; do
		pids+=("$pid")
	done < <(pgrep -f "$process_name" || true)
	
	# Check if any processes found
	if [[ ${#pids[@]} -eq 0 ]]; then
		error_exit "No processes matching '$process_name' found."
	fi
	
	echo "Found ${#pids[@]} process(es) matching '$process_name':"
	echo ""
	
	# Display all matching processes
	for pid in "${pids[@]}"; do
		if ps -p "$pid" > /dev/null 2>&1; then
			echo "─────────────────────────────────────────────────────"
			get_process_info "$pid"
		fi
	done
	
	echo ""
	read -r -p "Kill all ${#pids[@]} matching processes? (yes/no): " confirmation
	
	if [[ ! "$confirmation" =~ ^[Yy][Ee][Ss]$ ]]; then
		echo "Operation cancelled."
		return 0
	fi
	
	# Kill all matching processes
	local killed=0
	for pid in "${pids[@]}"; do
		if ps -p "$pid" > /dev/null 2>&1; then
			if kill -TERM "$pid" 2>/dev/null; then
				((++killed))
				echo "✓ Sent SIGTERM to PID $pid"
			fi
		fi
	done
	
	# Wait for graceful termination
	sleep 2
	
	# Force-kill any remaining processes
	for pid in "${pids[@]}"; do
		if ps -p "$pid" > /dev/null 2>&1; then
			kill -9 "$pid" 2>/dev/null || true
			echo "✓ Force-killed PID $pid with SIGKILL"
		fi
	done
	
	echo ""
	echo "Killed $killed process(es)."
}

# ============================================================================
# monitor_processes()
# Continuous monitoring with auto-refresh
# Args: refresh_interval (integer, seconds)
# ============================================================================
monitor_processes() {
	local refresh_interval="${1:-5}"
	
	if ! validate_numeric "$refresh_interval"; then
		error_exit "Refresh interval must be a number (seconds)"
	fi
	
	trap 'echo ""; echo "Monitoring stopped."; exit 0' INT
	
	while true; do
		clear
		display_dashboard "$TOP_LIMIT"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "Refreshing in $refresh_interval seconds (Press Ctrl+C to stop)..."
		sleep "$refresh_interval"
	done
}

################################################################################
# MAIN
################################################################################

main() {
	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--kill-pid)
				[[ $# -lt 2 ]] && error_exit "Missing PID for --kill-pid"
				kill_process_by_pid "$2"
				exit 0
				;;
			--kill-name)
				[[ $# -lt 2 ]] && error_exit "Missing process name for --kill-name"
				kill_process_by_name "$2"
				exit 0
				;;
			--monitor)
				local refresh=5
				if [[ $# -gt 1 ]] && [[ "$2" != --* ]]; then
					refresh="$2"
					shift
				fi
				monitor_processes "$refresh"
				exit 0
				;;
			--top)
				[[ $# -lt 2 ]] && error_exit "Missing number for --top"
				display_dashboard "$2"
				exit 0
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
	
	# Default: show dashboard
	display_dashboard "$TOP_LIMIT"
}

# Execute main function with all arguments
main "$@"

################################################################################
# EXAMPLE OUTPUT
################################################################################
#
# ╔════════════════════════════════════════════════════════════════╗
# ║                  PROCESS MONITOR DASHBOARD                    ║
# ║                   2026-03-25 14:32:47                          ║
# ╚════════════════════════════════════════════════════════════════╝
#
# Legend: PID | User | CPU% | MEM% | Command
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOP 10 CPU-CONSUMING PROCESSES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#    256 root              45.2  12.3  /opt/app/compute_engine
#   1234 ubuntu             8.5   3.2  python3 analytics.py
#   5678 mysql              3.4  18.9  /usr/sbin/mysqld
#   9012 nginx              1.2   0.8  nginx: worker process
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOP 10 MEMORY-CONSUMING PROCESSES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   5678 mysql              1.2  26.4  /usr/sbin/mysqld
#    256 root              45.2  12.3  /opt/app/compute_engine
#   3456 www-data           0.5   8.1  /usr/local/bin/memcached
#   1234 ubuntu             8.5   3.2  python3 analytics.py
#
################################################################################
