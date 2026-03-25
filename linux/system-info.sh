#!/bin/bash
################################################################################
# system-info.sh - Display comprehensive system information dashboard
# 
# EXECUTION:
#   chmod +x system-info.sh
#   ./system-info.sh              # Display full system report
#   ./system-info.sh --help       # Show usage information
#
# DESCRIPTION:
#   Provides a clean, formatted dashboard showing:
#   - CPU information (model, cores, current usage)
#   - RAM usage (total, used, free, percentage)
#   - Disk usage per mountpoint (human-readable)
#   - System uptime
#   - Load average (1, 5, 15 minute)
#
# REQUIREMENTS:
#   - Linux system with: lscpu, top, free, df, uptime, awk, grep
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

# Global variables
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

################################################################################
# FUNCTIONS
################################################################################

# ============================================================================
# display_help()
# Display usage information and examples
# ============================================================================
display_help() {
	cat <<-EOF
		Usage: $SCRIPT_NAME [OPTION]
		
		Display system information including CPU, RAM, disk usage, uptime, and load average.
		
		OPTIONS:
		  --help, -h       Show this help message
		  --version, -v    Show script version
		
		EXAMPLES:
		  $SCRIPT_NAME                    # Display full system information
		  $SCRIPT_NAME --help              # Show this help message
		
		OUTPUT:
		  The dashboard includes:
		    - CPU model and core count
		    - Current CPU usage percentage
		    - RAM total, used, and free (with percentage)
		    - Disk usage for all mounted filesystems
		    - System uptime in human-readable format
		    - Load average (1, 5, 15 minute averages)
		
		NOTES:
		  - Requires standard Linux utilities (lscpu, top, free, df, uptime)
		  - No elevated privileges required
		  - Data is current as of execution time
		  - Load average on systems with fewer cores may appear high
		
	EOF
}

# ============================================================================
# get_cpu_info()
# Extract CPU model and core count using lscpu
# ============================================================================
get_cpu_info() {
	local cpu_model=""
	local cpu_cores=""
	
	# Get CPU model name
	cpu_model=$(lscpu | grep "Model name:" | sed 's/^[^:]*: //' || echo "N/A")
	
	# Get number of CPUs (logical cores)
	cpu_cores=$(lscpu | grep "^CPU(s):" | grep -oE '[0-9]+' | head -1 || echo "N/A")
	
	echo "CPU Model:    $cpu_model"
	echo "CPU Cores:    $cpu_cores"
}

# ============================================================================
# get_cpu_usage()
# Calculate current CPU usage percentage using top
# Returns average CPU usage across all cores
# ============================================================================
get_cpu_usage() {
	local cpu_usage=""
	
	# Run top in batch mode for 1 iteration, extract CPU usage
	# Focuses on %Cpu(s) line which shows overall CPU usage
	cpu_usage=$(top -bn1 | grep "%Cpu(s)" | awk '{print $2}' | sed 's/%us,//g' || echo "N/A")
	
	# If we got a value, it's the user CPU time; calculate approximation
	if [[ "$cpu_usage" != "N/A" ]]; then
		# Alternative: use entire CPU line for more accurate reading
		cpu_usage=$(top -bn1 | grep "%Cpu(s)" | awk -F',' '{print $4}' | sed 's/% id,//g' | awk '{print 100 - $1}' || echo "N/A")
	fi
	
	echo "CPU Usage:    ${cpu_usage}%"
}

# ============================================================================
# get_memory_info()
# Extract memory information using free command
# Returns total, used, free memory in human-readable format
# ============================================================================
get_memory_info() {
	local mem_total=""
	local mem_used=""
	local mem_free=""
	local mem_percent=""
	
	# Parse free output; use 'available' for better accuracy on systems with cache
	mem_total=$(free -h | grep "^Mem:" | awk '{print $2}')
	mem_used=$(free -h | grep "^Mem:" | awk '{print $3}')
	mem_free=$(free -h | grep "^Mem:" | awk '{print $4}')
	
	# Calculate percentage used
	mem_percent=$(free | grep "^Mem:" | awk '{printf "%.1f", ($3 / $2) * 100}')
	
	echo "Memory Total: $mem_total"
	echo "Memory Used:  $mem_used (${mem_percent}%)"
	echo "Memory Free:  $mem_free"
}

# ============================================================================
# get_disk_usage()
# Display disk usage for all mounted filesystems
# Shows mountpoint, size, used, available, and percentage
# ============================================================================
get_disk_usage() {
	local -i count=0
	
	# Use df to get filesystem information; format output
	# Skip pseudo-filesystems (tmpfs, devtmpfs, squashfs)
	while IFS= read -r line; do
		if [[ $count -eq 0 ]]; then
			# Print header
			echo "$line" | awk '{printf "%-30s %12s %12s %12s %8s\n", "Filesystem", "Size", "Used", "Available", "Use%"}'
			((++count))
		else
			# Print data rows; filter out unimportant filesystems
			echo "$line" | awk '{printf "%-30s %12s %12s %12s %8s\n", $1, $2, $3, $4, $5}'
		fi
	done < <(df -h | grep -vE "tmpfs|devtmpfs|squashfs|overlay")
}

# ============================================================================
# get_uptime()
# Extract system uptime in human-readable format
# ============================================================================
get_uptime() {
	local uptime_info=""
	
	# Get uptime; remove the "up" prefix and "load average" suffix
	uptime_info=$(uptime | sed 's/^.*up \(.*\),  *[0-9]* user.*/\1/')
	
	echo "Uptime:       $uptime_info"
}

# ============================================================================
# get_load_average()
# Extract load average for 1, 5, and 15 minute intervals
# ============================================================================
get_load_average() {
	local load_avg=""
	
	# Extract load average from uptime or /proc/loadavg
	load_avg=$(cat /proc/loadavg | awk '{printf "%s %s %s", $1, $2, $3}')
	
	echo "Load Average: $load_avg (1min, 5min, 15min)"
}

# ============================================================================
# display_dashboard()
# Main function: orchestrate all data collection and formatted output
# ============================================================================
display_dashboard() {
	# Print header
	echo ""
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║                   SYSTEM INFORMATION                           ║"
	echo "║                   $(date '+%Y-%m-%d %H:%M:%S')                           ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	echo ""
	
	# CPU Section
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "CPU INFORMATION"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	get_cpu_info
	get_cpu_usage
	echo ""
	
	# Memory Section
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "MEMORY INFORMATION"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	get_memory_info
	echo ""
	
	# Disk Section
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "DISK USAGE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	get_disk_usage
	echo ""
	
	# System Section
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "SYSTEM STATE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	get_uptime
	get_load_average
	echo ""
}

################################################################################
# MAIN
################################################################################

main() {
	# Parse command-line arguments
	case "${1:-}" in
		--help|-h)
			display_help
			exit 0
			;;
		--version|-v)
			echo "$SCRIPT_NAME version $VERSION"
			exit 0
			;;
		"")
			# No arguments; display dashboard
			display_dashboard
			;;
		*)
			echo "Error: Unknown option '$1'" >&2
			echo "Use '$SCRIPT_NAME --help' for usage information" >&2
			exit 1
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
# ║                   SYSTEM INFORMATION                           ║
# ║                   2026-03-25 14:32:47                          ║
# ╚════════════════════════════════════════════════════════════════╝
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CPU INFORMATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CPU Model:    Intel(R) Core(TM) i7-8700K CPU @ 3.70GHz
# CPU Cores:    6
# CPU Usage:    24.3%
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MEMORY INFORMATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Memory Total: 15Gi
# Memory Used:  8.2Gi (54.7%)
# Memory Free:  6.8Gi
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISK USAGE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Filesystem                          Size         Used    Available     Use%
# /dev/sda1                            465G        245G         189G      55%
# /dev/sdb1                             1T        512G         488G      51%
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYSTEM STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Uptime:       45 days, 12:03
# Load Average: 1.23 1.45 0.98 (1min, 5min, 15min)
#
################################################################################
