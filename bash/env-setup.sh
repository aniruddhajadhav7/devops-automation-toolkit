#!/bin/bash

################################################################################
# env-setup.sh
# Description: Bootstrap a fresh Linux machine with essential packages and
#              configurations for DevOps automation
# Author: DevOps Automation Toolkit
# Usage: sudo ./env-setup.sh
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/env-setup_$(date +%Y%m%d_%H%M%S).log"
SETUP_DIR="/opt/devops-setup"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo $0"
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error_exit "Cannot detect Linux distribution"
    fi
    log "INFO" "Detected OS: $OS $VERSION"
}

update_system() {
    log "INFO" "Updating system packages..."
    case "$OS" in
        ubuntu|debian)
            apt-get update -qq
            apt-get upgrade -y -qq
            ;;
        centos|rhel|fedora)
            yum update -y -q
            ;;
        alpine)
            apk update
            apk upgrade
            ;;
        *)
            log "WARN" "Unknown distro, skipping update"
            ;;
    esac
}

install_essential_packages() {
    log "INFO" "Installing essential packages..."

    case "$OS" in
        ubuntu|debian)
            apt-get install -y -qq \
                curl wget git vim nano htop \
                net-tools dnsutils iputils-ping \
                tar gzip zip unzip \
                jq yq \
                openssh-client openssh-server \
                sudo cron \
                ca-certificates
            ;;
        centos|rhel|fedora)
            yum install -y -q \
                curl wget git vim nano htop \
                net-tools bind-utils iputils \
                tar gzip zip unzip \
                jq yq \
                openssh-clients openssh-server \
                sudo cronie \
                ca-certificates
            ;;
        alpine)
            apk add --no-cache \
                curl wget git vim nano htop \
                net-tools bind-tools iputils \
                tar gzip zip unzip \
                jq yq \
                openssh openssh-client \
                sudo dcron \
                ca-certificates
            ;;
        *)
            log "WARN" "Package installation skipped for unknown distro"
            ;;
    esac
}

install_container_tools() {
    log "INFO" "Installing container tools..."

    case "$OS" in
        ubuntu|debian)
            apt-get install -y -qq docker.io docker-compose containerd
            systemctl enable docker
            systemctl start docker
            ;;
        centos|rhel)
            yum install -y -q docker docker-compose
            systemctl enable docker
            systemctl start docker
            ;;
        alpine)
            apk add --no-cache docker docker-compose containerd
            ;;
        *)
            log "WARN" "Docker installation skipped for unknown distro"
            ;;
    esac
}

install_dev_tools() {
    log "INFO" "Installing development tools..."

    case "$OS" in
        ubuntu|debian)
            apt-get install -y -qq build-essential python3 python3-pip nodejs npm
            ;;
        centos|rhel)
            yum groupinstall -y -q "Development Tools"
            yum install -y -q python3 python3-pip nodejs npm
            ;;
        alpine)
            apk add --no-cache build-base python3 py3-pip nodejs npm
            ;;
        *)
            log "WARN" "Dev tools installation skipped for unknown distro"
            ;;
    esac
}

configure_firewall() {
    log "INFO" "Configuring firewall..."

    case "$OS" in
        ubuntu|debian|centos|rhel)
            systemctl enable ufw 2>/dev/null || systemctl enable firewalld 2>/dev/null || true
            ;;
        *)
            log "WARN" "Firewall configuration skipped for unknown distro"
            ;;
    esac
}

setup_user() {
    local username="${1:-devops}"
    log "INFO" "Setting up user: $username"

    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash -G docker,sudo "$username" 2>/dev/null || true
        log "INFO" "Created user: $username"
    else
        log "INFO" "User already exists: $username"
    fi
}

setup_cron() {
    log "INFO" "Setting up cron service..."

    case "$OS" in
        ubuntu|debian)
            systemctl enable cron
            systemctl start cron
            ;;
        centos|rhel|fedora)
            systemctl enable crond
            systemctl start crond
            ;;
        alpine)
            rc-update add dcron default 2>/dev/null || true
            rc-service dcron start 2>/dev/null || true
            ;;
        *)
            log "WARN" "Cron setup skipped for unknown distro"
            ;;
    esac
}

setup_logging() {
    log "INFO" "Setting up logging directory..."
    mkdir -p "$SETUP_DIR"
    chmod 755 "$SETUP_DIR"
    log "INFO" "Setup directory created: $SETUP_DIR"
}

################################################################################
# Main Script
################################################################################

echo -e "${BLUE}═══ System Environment Setup ═══${NC}"

check_root
detect_distro
update_system
install_essential_packages
install_container_tools
install_dev_tools
configure_firewall
setup_user "devops"
setup_cron
setup_logging

log "INFO" "System setup completed successfully"
echo -e "\n${GREEN}✓ Environment setup completed!${NC}"
echo -e "Log file: ${YELLOW}${LOG_FILE}${NC}"
