#!/bin/bash

################################################################################
# health-check.sh
# Description: Service health check script with ping, HTTP checks, and alerts
# Author: DevOps Automation Toolkit
# Usage: ./health-check.sh
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"
LOG_FILE="./health_check_$(date +%Y%m%d).log"
FAILED_SERVICES=()
PASSED_SERVICES=()

# Services to monitor (format: "name:host:port:check_type")
# check_type: ping, http, tcp
declare -a SERVICES=(
    "DNS:8.8.8.8:53:ping"
    "Google:google.com:80:http"
    "Localhost:127.0.0.1:22:tcp"
)

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

check_ping() {
    local host=$1
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_http() {
    local host=$1
    local port=${2:-80}
    local timeout=5

    if curl -s -m "$timeout" -o /dev/null -w "%{http_code}" "http://${host}:${port}/" 2>/dev/null | grep -q "200\|301\|302"; then
        return 0
    else
        return 1
    fi
}

check_tcp() {
    local host=$1
    local port=$2
    local timeout=5

    if timeout "$timeout" bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_service() {
    local name=$1
    local host=$2
    local port=$3
    local check_type=$4

    echo -n "Checking ${name}... "

    case "$check_type" in
        ping)
            if check_ping "$host"; then
                echo -e "${GREEN}✓ UP${NC}"
                PASSED_SERVICES+=("$name")
                log "INFO" "$name: UP (ping check)"
                return 0
            else
                echo -e "${RED}✗ DOWN${NC}"
                FAILED_SERVICES+=("$name")
                log "ERROR" "$name: DOWN (ping check failed)"
                return 1
            fi
            ;;
        http)
            if check_http "$host" "$port"; then
                echo -e "${GREEN}✓ UP${NC}"
                PASSED_SERVICES+=("$name")
                log "INFO" "$name: UP (HTTP check)"
                return 0
            else
                echo -e "${RED}✗ DOWN${NC}"
                FAILED_SERVICES+=("$name")
                log "ERROR" "$name: DOWN (HTTP check failed)"
                return 1
            fi
            ;;
        tcp)
            if check_tcp "$host" "$port"; then
                echo -e "${GREEN}✓ UP${NC}"
                PASSED_SERVICES+=("$name")
                log "INFO" "$name: UP (TCP check on port $port)"
                return 0
            else
                echo -e "${RED}✗ DOWN${NC}"
                FAILED_SERVICES+=("$name")
                log "ERROR" "$name: DOWN (TCP check on port $port failed)"
                return 1
            fi
            ;;
        *)
            echo -e "${YELLOW}? UNKNOWN${NC}"
            log "WARN" "$name: Unknown check type '$check_type'"
            return 2
            ;;
    esac
}

send_alert() {
    local failed_count=${#FAILED_SERVICES[@]}
    local passed_count=${#PASSED_SERVICES[@]}

    if [[ $failed_count -gt 0 ]]; then
        local subject="⚠️ Health Check Alert: $failed_count service(s) down"
        local body="Health check completed at $(date '+%Y-%m-%d %H:%M:%S')\n\n"
        body+="Failed Services (${failed_count}):\n"
        for service in "${FAILED_SERVICES[@]}"; do
            body+="  • $service\n"
        done
        body+="\nPassed Services (${passed_count}):\n"
        for service in "${PASSED_SERVICES[@]}"; do
            body+="  • $service\n"
        done

        log "INFO" "Sending alert to $ALERT_EMAIL"
        # Uncomment to enable email alerts (requires mail command)
        # echo -e "$body" | mail -s "$subject" "$ALERT_EMAIL"

        # For now, just log the alert content
        echo -e "\n${RED}ALERT:${NC} $subject\n$body" | tee -a "$LOG_FILE"
    fi
}

################################################################################
# Main Script
################################################################################

echo -e "${BLUE}═══ Service Health Check ═══${NC}"
log "INFO" "Starting health check..."

for service in "${SERVICES[@]}"; do
    IFS=':' read -r name host port check_type <<< "$service"
    check_service "$name" "$host" "$port" "$check_type"
done

echo ""
echo -e "${BLUE}═══ Summary ═══${NC}"
echo -e "Passed: ${GREEN}${#PASSED_SERVICES[@]}${NC} | Failed: ${RED}${#FAILED_SERVICES[@]}${NC}"

send_alert

log "INFO" "Health check completed"
