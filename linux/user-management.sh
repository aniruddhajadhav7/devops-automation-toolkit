#!/bin/bash
################################################################################
# user-management.sh - Manage local users and groups
#
# EXECUTION:
#   chmod +x user-management.sh
#   ./user-management.sh --create username
#   ./user-management.sh --delete username
#   ./user-management.sh --add-group username groupname
#   ./user-management.sh --remove-group username groupname
#   ./user-management.sh --list
#
# DESCRIPTION:
#   Provides user and group management functionality with safety checks:
#   - Create new user accounts with home directory
#   - Delete users and their home directories
#   - Add users to supplementary groups
#   - Remove users from groups
#   - List all users with UIDs
#   - Log all actions to /var/log/user-management.log
#
# REQUIREMENTS:
#   - Linux system with: useradd, userdel, usermod, groupadd, id, grep
#   - sudo privileges or root access
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
readonly LOG_FILE="/var/log/user-management.log"
readonly MIN_UID=1000  # Minimum UID for regular users

################################################################################
# UTILITY FUNCTIONS
################################################################################

# ============================================================================
# log_action()
# Log executed action with timestamp to log file
# Args: message (string)
# ============================================================================
log_action() {
	local message="$1"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	local log_entry="[$timestamp] $message"
	
	# Try to write to log file; fail gracefully if no permissions
	if [[ -w "$LOG_FILE" ]] || sudo touch "$LOG_FILE" 2>/dev/null; then
		echo "$log_entry" | sudo tee -a "$LOG_FILE" > /dev/null
	fi
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
# require_sudo()
# Check if script has sudo privileges; prompt if needed
# ============================================================================
require_sudo() {
	if [[ $EUID -ne 0 ]]; then
		# Not running as root; try to elevate
		if ! sudo -n true 2>/dev/null; then
			echo "This operation requires sudo privileges."
			echo "Please re-run the script with sudo or configure passwordless sudo."
			exit 1
		fi
	fi
}

# ============================================================================
# display_help()
# Display usage information and examples
# ============================================================================
display_help() {
	cat <<-EOF
		Usage: $SCRIPT_NAME [OPTION] [ARGUMENTS]
		
		Manage local users and groups with comprehensive logging and safety checks.
		
		OPTIONS:
		  --create USERNAME              Create new user with home directory
		  --delete USERNAME              Delete user and home directory
		  --add-group USERNAME GROUP     Add user to supplementary group
		  --remove-group USERNAME GROUP  Remove user from group
		  --list                         List all users with UIDs
		  --help, -h                     Show this help message
		  --version, -v                  Show script version
		
		EXAMPLES:
		  $SCRIPT_NAME --create john_doe
		  $SCRIPT_NAME --delete john_doe
		  $SCRIPT_NAME --add-group john_doe sudo
		  $SCRIPT_NAME --add-group john_doe docker
		  $SCRIPT_NAME --remove-group john_doe sudo
		  $SCRIPT_NAME --list
		  
		NOTES:
		  - All operations require sudo or root privileges
		  - Minimum UID for regular users is set to $MIN_UID
		  - All actions are logged to $LOG_FILE
		  - Destructive operations (delete) require confirmation
		  - Group must exist before adding user to it
		  - User must exist before modifying group membership
		
		LOG FILE:
		  $LOG_FILE
		  View recent actions: tail -20 $LOG_FILE
		
	EOF
}

# ============================================================================
# validate_username()
# Validate username format
# Args: username (string)
# Returns: 0 if valid, 1 if invalid
# ============================================================================
validate_username() {
	local username="$1"
	
	# Username must be 3-32 characters, start with letter, contain only
	# lowercase letters, digits, and underscores
	if [[ $username =~ ^[a-z][a-z0-9_]{2,31}$ ]]; then
		return 0
	else
		echo "ERROR: Invalid username format." >&2
		echo "  Username must be 3-32 characters, start with a letter," >&2
		echo "  and contain only lowercase letters, digits, and underscores." >&2
		return 1
	fi
}

# ============================================================================
# validate_groupname()
# Validate group name format
# Args: groupname (string)
# Returns: 0 if valid, 1 if invalid
# ============================================================================
validate_groupname() {
	local groupname="$1"
	
	if [[ $groupname =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
		return 0
	else
		echo "ERROR: Invalid group name format." >&2
		return 1
	fi
}

# ============================================================================
# user_exists()
# Check if user exists in system
# Args: username (string)
# Returns: 0 if exists, 1 if not
# ============================================================================
user_exists() {
	local username="$1"
	id "$username" &>/dev/null && return 0 || return 1
}

# ============================================================================
# group_exists()
# Check if group exists in system
# Args: groupname (string)
# Returns: 0 if exists, 1 if not
# ============================================================================
group_exists() {
	local groupname="$1"
	getent group "$groupname" &>/dev/null && return 0 || return 1
}

# ============================================================================
# user_in_group()
# Check if user belongs to group
# Args: username (string), groupname (string)
# Returns: 0 if yes, 1 if no
# ============================================================================
user_in_group() {
	local username="$1"
	local groupname="$2"
	groups "$username" | grep -qw "$groupname" && return 0 || return 1
}

################################################################################
# ACTION FUNCTIONS
################################################################################

# ============================================================================
# create_user()
# Create new user account with home directory
# Args: username (string)
# ============================================================================
create_user() {
	local username="$1"
	
	# Validate input
	validate_username "$username" || return 1
	
	# Check if user already exists
	if user_exists "$username"; then
		error_exit "User '$username' already exists."
	fi
	
	# Create the user
	require_sudo
	if sudo useradd -m -s /bin/bash "$username" 2>/dev/null; then
		log_action "INFO: Created user '$username' (UID: $(id -u "$username"))"
		echo "✓ User '$username' created successfully."
		return 0
	else
		log_action "ERROR: Failed to create user '$username'"
		error_exit "Failed to create user '$username'."
	fi
}

# ============================================================================
# delete_user()
# Delete user and home directory
# Args: username (string)
# ============================================================================
delete_user() {
	local username="$1"
	local uid
	
	# Validate input
	validate_username "$username" || return 1
	
	# Check if user exists
	if ! user_exists "$username"; then
		error_exit "User '$username' does not exist."
	fi
	
	# Get UID before deletion
	uid=$(id -u "$username")
	
	# Require confirmation
	echo "WARNING: This will delete user '$username' and their home directory."
	read -r -p "Are you sure? (yes/no): " confirm
	
	if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
		echo "Operation cancelled."
		return 0
	fi
	
	# Delete the user
	require_sudo
	if sudo userdel -r "$username" 2>/dev/null; then
		log_action "INFO: Deleted user '$username' (UID: $uid)"
		echo "✓ User '$username' deleted successfully."
		return 0
	else
		log_action "ERROR: Failed to delete user '$username'"
		error_exit "Failed to delete user '$username'."
	fi
}

# ============================================================================
# add_user_to_group()
# Add user to supplementary group
# Args: username (string), groupname (string)
# ============================================================================
add_user_to_group() {
	local username="$1"
	local groupname="$2"
	
	# Validate input
	validate_username "$username" || return 1
	validate_groupname "$groupname" || return 1
	
	# Check prerequisites
	if ! user_exists "$username"; then
		error_exit "User '$username' does not exist."
	fi
	
	if ! group_exists "$groupname"; then
		error_exit "Group '$groupname' does not exist."
	fi
	
	# Check if user already in group
	if user_in_group "$username" "$groupname"; then
		echo "User '$username' is already in group '$groupname'."
		return 0
	fi
	
	# Add user to group
	require_sudo
	if sudo usermod -aG "$groupname" "$username" 2>/dev/null; then
		log_action "INFO: Added user '$username' to group '$groupname'"
		echo "✓ User '$username' added to group '$groupname'."
		echo "  Note: User must log out and log back in for group changes to take effect."
		return 0
	else
		log_action "ERROR: Failed to add user '$username' to group '$groupname'"
		error_exit "Failed to add user '$username' to group '$groupname'."
	fi
}

# ============================================================================
# remove_user_from_group()
# Remove user from supplementary group
# Args: username (string), groupname (string)
# ============================================================================
remove_user_from_group() {
	local username="$1"
	local groupname="$2"
	
	# Validate input
	validate_username "$username" || return 1
	validate_groupname "$groupname" || return 1
	
	# Check prerequisites
	if ! user_exists "$username"; then
		error_exit "User '$username' does not exist."
	fi
	
	if ! group_exists "$groupname"; then
		error_exit "Group '$groupname' does not exist."
	fi
	
	# Check if user is in group
	if ! user_in_group "$username" "$groupname"; then
		echo "User '$username' is not in group '$groupname'."
		return 0
	fi
	
	# Remove user from group
	require_sudo
	# Note: usermod with -G replaces groups; use gpasswd for removal
	if sudo gpasswd -d "$username" "$groupname" 2>/dev/null; then
		log_action "INFO: Removed user '$username' from group '$groupname'"
		echo "✓ User '$username' removed from group '$groupname'."
		return 0
	else
		log_action "ERROR: Failed to remove user '$username' from group '$groupname'"
		error_exit "Failed to remove user '$username' from group '$groupname'."
	fi
}

# ============================================================================
# list_users()
# Display all regular users (UID >= MIN_UID) with their details
# ============================================================================
list_users() {
	echo ""
	echo "Regular Users on System (UID >= $MIN_UID):"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	printf "%-20s %8s %30s %20s\n" "Username" "UID" "Full Name" "Home Directory"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	# Parse /etc/passwd for users with UID >= MIN_UID
	while IFS=: read -r username _ uid gid fullname homedir _; do
		if [[ $uid -ge $MIN_UID ]] && [[ -n "$username" ]]; then
			printf "%-20s %8d %30s %20s\n" "$username" "$uid" "$fullname" "$homedir"
		fi
	done < /etc/passwd
	
	echo ""
}

################################################################################
# MAIN
################################################################################

main() {
	# Validate at least one argument provided
	if [[ $# -eq 0 ]]; then
		display_help
		exit 1
	fi
	
	# Parse command-line arguments
	case "$1" in
		--create)
			[[ $# -lt 2 ]] && error_exit "Missing username argument for --create"
			create_user "$2"
			;;
		--delete)
			[[ $# -lt 2 ]] && error_exit "Missing username argument for --delete"
			delete_user "$2"
			;;
		--add-group)
			[[ $# -lt 3 ]] && error_exit "Missing username or group argument for --add-group"
			add_user_to_group "$2" "$3"
			;;
		--remove-group)
			[[ $# -lt 3 ]] && error_exit "Missing username or group argument for --remove-group"
			remove_user_from_group "$2" "$3"
			;;
		--list)
			list_users
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
			echo "ERROR: Unknown option '$1'" >&2
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
# $ ./user-management.sh --create john_doe
# ✓ User 'john_doe' created successfully.
#
# $ ./user-management.sh --add-group john_doe sudo
# ✓ User 'john_doe' added to group 'sudo'.
#   Note: User must log out and log back in for group changes to take effect.
#
# $ ./user-management.sh --list
#
# Regular Users on System (UID >= 1000):
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Username               UID Full Name                 Home Directory
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# john_doe             1001 John Doe                   /home/john_doe
# jane_smith           1002 Jane Smith                 /home/jane_smith
# bob_wilson           1003 Bob Wilson                 /home/bob_wilson
#
# $ tail -5 /var/log/user-management.log
# [2026-03-25 14:32:15] INFO: Created user 'john_doe' (UID: 1001)
# [2026-03-25 14:33:42] INFO: Added user 'john_doe' to group 'sudo'
# [2026-03-25 14:35:01] ERROR: User 'jane' does not exist
# [2026-03-25 14:36:20] INFO: Removed user 'john_doe' from group 'docker'
# [2026-03-25 14:37:45] INFO: Deleted user 'john_doe' (UID: 1001)
#
################################################################################
