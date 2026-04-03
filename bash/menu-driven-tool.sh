#!/bin/bash

################################################################################
# menu-driven-tool.sh
# Description: Interactive CLI menu for common system administration tasks
# Author: DevOps Automation Toolkit
# Usage: ./menu-driven-tool.sh
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/sysadmin_tool_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$LOG_DIR"
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}System Administration Menu${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}\n"
}

print_menu() {
    echo -e "${YELLOW}Select an option:${NC}\n"
    echo -e "  ${CYAN}1${NC}) System Information"
    echo -e "  ${CYAN}2${NC}) Disk Usage Report"
    echo -e "  ${CYAN}3${NC}) Memory & CPU Status"
    echo -e "  ${CYAN}4${NC}) Network Configuration"
    echo -e "  ${CYAN}5${NC}) Process Management"
    echo -e "  ${CYAN}6${NC}) User Management"
    echo -e "  ${CYAN}7${NC}) Service Management"
    echo -e "  ${CYAN}8${NC}) Firewall Status"
    echo -e "  ${CYAN}9${NC}) Log Viewer"
    echo -e "  ${CYAN}10${NC}) Exit"
    echo ""
}

system_info() {
    log "INFO" "System information requested"
    print_header
    echo -e "${GREEN}═══ System Information ═══${NC}\n"

    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}OS:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Uptime:${NC} $(uptime -p)"
    echo -e "${CYAN}CPU Cores:${NC} $(nproc)"
    echo -e "${CYAN}Total Memory:${NC} $(free -h | awk '/^Mem:/ {print $2}')"

    echo ""
    read -p "Press Enter to continue..."
}

disk_usage() {
    log "INFO" "Disk usage report requested"
    print_header
    echo -e "${GREEN}═══ Disk Usage Report ═══${NC}\n"

    df -h | awk 'NR==1 {print} NR>1 {printf "%-20s %8s %8s %8s %5s %s\n", $1, $2, $3, $4, $5, $6}'

    echo ""
    echo -e "${YELLOW}Largest directories in /home:${NC}"
    du -sh /home/* 2>/dev/null | sort -rh | head -5 || echo "No directories found"

    echo ""
    read -p "Press Enter to continue..."
}

memory_cpu_status() {
    log "INFO" "Memory and CPU status requested"
    print_header
    echo -e "${GREEN}═══ Memory & CPU Status ═══${NC}\n"

    echo -e "${CYAN}Memory Usage:${NC}"
    free -h

    echo ""
    echo -e "${CYAN}CPU Load Average:${NC}"
    uptime | awk -F'load average:' '{print $2}'

    echo ""
    echo -e "${CYAN}Top 5 Processes by CPU:${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5

    echo ""
    echo -e "${CYAN}Top 5 Processes by Memory:${NC}"
    ps aux --sort=-%mem | head -6 | tail -5

    echo ""
    read -p "Press Enter to continue..."
}

network_config() {
    log "INFO" "Network configuration requested"
    print_header
    echo -e "${GREEN}═══ Network Configuration ═══${NC}\n"

    echo -e "${CYAN}Network Interfaces:${NC}"
    ip addr show | grep "inet " | awk '{print $NF, "→", $2}'

    echo ""
    echo -e "${CYAN}Network Statistics:${NC}"
    netstat -tuln 2>/dev/null | grep LISTEN || ss -tuln | grep LISTEN

    echo ""
    echo -e "${CYAN}DNS Configuration:${NC}"
    cat /etc/resolv.conf | grep nameserver | head -3 || echo "No DNS configured"

    echo ""
    read -p "Press Enter to continue..."
}

process_management() {
    log "INFO" "Process management menu requested"
    print_header
    echo -e "${GREEN}═══ Process Management ═══${NC}\n"

    echo -e "${CYAN}Running Processes:${NC}"
    ps aux | head -11 | tail -10

    echo ""
    read -p "Enter process name to search (or press Enter to skip): " process_name
    if [[ -n "$process_name" ]]; then
        echo -e "\n${CYAN}Search results for: $process_name${NC}"
        ps aux | grep "$process_name" | grep -v grep || echo "No processes found"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

user_management() {
    log "INFO" "User management menu requested"
    print_header
    echo -e "${GREEN}═══ User Management ═══${NC}\n"

    echo -e "${CYAN}System Users (last 5):${NC}"
    tail -5 /etc/passwd | awk -F':' '{print $1, "→", $3, "(UID)"}'

    echo ""
    read -p "Press Enter to continue..."
}

service_management() {
    log "INFO" "Service management menu requested"
    print_header
    echo -e "${GREEN}═══ Service Management ═══${NC}\n"

    echo -e "${YELLOW}Active services:${NC}"
    systemctl list-units --type=service --state=running --no-pager | grep -E "\.service" | head -10 || true

    echo ""
    read -p "Press Enter to continue..."
}

firewall_status() {
    log "INFO" "Firewall status requested"
    print_header
    echo -e "${GREEN}═══ Firewall Status ═══${NC}\n"

    if command -v ufw &>/dev/null; then
        echo -e "${CYAN}UFW Status:${NC}"
        ufw status || echo "UFW not enabled"
    elif command -v firewall-cmd &>/dev/null; then
        echo -e "${CYAN}FirewallD Status:${NC}"
        firewall-cmd --state
        echo ""
        echo -e "${CYAN}Active Rules:${NC}"
        firewall-cmd --list-all
    else
        echo -e "${YELLOW}No firewall tools detected${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

log_viewer() {
    log "INFO" "Log viewer menu requested"
    print_header
    echo -e "${GREEN}═══ Log Viewer ═══${NC}\n"

    echo -e "${CYAN}1) System Log (last 20 lines)${NC}"
    echo -e "${CYAN}2) Kernel Log (last 20 lines)${NC}"
    echo -e "${CYAN}3) Auth Log (last 20 lines)${NC}"
    echo -e "${CYAN}4) Back to main menu${NC}"
    echo ""
    read -p "Select option: " log_choice

    case $log_choice in
        1)
            echo ""
            journalctl -n 20 --no-pager || tail -20 /var/log/syslog 2>/dev/null || echo "Log not available"
            ;;
        2)
            echo ""
            dmesg | tail -20
            ;;
        3)
            echo ""
            tail -20 /var/log/auth.log 2>/dev/null || tail -20 /var/log/secure 2>/dev/null || echo "Auth log not available"
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# Main Loop
################################################################################

main() {
    mkdir -p "$LOG_DIR"
    log "INFO" "System administration menu started"

    while true; do
        print_header
        print_menu
        read -p "Enter choice [1-10]: " choice

        case $choice in
            1) system_info ;;
            2) disk_usage ;;
            3) memory_cpu_status ;;
            4) network_config ;;
            5) process_management ;;
            6) user_management ;;
            7) service_management ;;
            8) firewall_status ;;
            9) log_viewer ;;
            10)
                log "INFO" "Menu closed by user"
                echo -e "\n${GREEN}Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

main "$@"
