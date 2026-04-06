#!/bin/bash

################################################################################
# Container Health Check Script
# Description: Monitor running Docker containers, detect unhealthy ones, and restart if needed
# Usage: ./container-health-check.sh [--alert-email EMAIL] [--check-interval SECONDS]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ALERT_EMAIL=""
CHECK_INTERVAL=60
MAX_RETRIES=3
RESTART_COOLDOWN=300  # 5 minutes cooldown before restart attempt
LOG_FILE="/var/log/docker-health-check.log"
STATE_DIR="/tmp/docker-health-check"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

################################################################################
# Functions
################################################################################

log_info() {
    local msg="$*"
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $msg" | tee -a "$LOG_FILE"
}

log_success() {
    local msg="$*"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $msg" | tee -a "$LOG_FILE"
}

log_warning() {
    local msg="$*"
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$*"
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $msg" | tee -a "$LOG_FILE"
}

show_help() {
    cat << EOF
Docker Container Health Check Utility

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --alert-email EMAIL         Email address for health alerts (requires mail command)
    --check-interval SECONDS    Interval between health checks (default: 60)
    --max-retries NUM           Max failed checks before restart (default: 3)
    --daemonize                 Run in background as daemon
    --help                      Show this help message

EXAMPLES:
    # Run health checks every 60 seconds
    $0

    # Custom check interval with email alerts
    $0 --check-interval 30 --alert-email ops@example.com

    # Run as daemon
    $0 --daemonize

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --alert-email)
                ALERT_EMAIL="$2"
                shift 2
                ;;
            --check-interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --daemonize)
                DAEMONIZE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

send_alert() {
    local subject="$1"
    local message="$2"

    if [[ -z "$ALERT_EMAIL" ]]; then
        return
    fi

    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log_info "Alert email sent to $ALERT_EMAIL"
    else
        log_warning "mail command not found, skipping email alert"
    fi
}

get_container_health() {
    local container_id="$1"

    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "none")

    echo "$health_status"
}

get_container_state() {
    local container_id="$1"

    local running
    running=$(docker inspect --format='{{.State.Running}}' "$container_id" 2>/dev/null || echo "false")

    echo "$running"
}

increment_failure_count() {
    local container_id="$1"
    local count_file="$STATE_DIR/${container_id}.failures"

    local current_count=0
    if [[ -f "$count_file" ]]; then
        current_count=$(cat "$count_file")
    fi

    echo $((current_count + 1)) > "$count_file"
}

reset_failure_count() {
    local container_id="$1"
    local count_file="$STATE_DIR/${container_id}.failures"

    rm -f "$count_file"
}

get_failure_count() {
    local container_id="$1"
    local count_file="$STATE_DIR/${container_id}.failures"

    if [[ -f "$count_file" ]]; then
        cat "$count_file"
    else
        echo 0
    fi
}

can_restart_container() {
    local container_id="$1"
    local last_restart_file="$STATE_DIR/${container_id}.last_restart"

    if [[ ! -f "$last_restart_file" ]]; then
        return 0  # First time, allow restart
    fi

    local last_restart
    last_restart=$(cat "$last_restart_file")

    local current_time
    current_time=$(date +%s)

    local time_elapsed=$((current_time - last_restart))

    if [[ $time_elapsed -lt $RESTART_COOLDOWN ]]; then
        return 1  # Still in cooldown period
    fi

    return 0  # Cooldown expired
}

mark_restart_time() {
    local container_id="$1"
    local last_restart_file="$STATE_DIR/${container_id}.last_restart"

    date +%s > "$last_restart_file"
}

restart_container() {
    local container_id="$1"
    local container_name="$2"

    log_warning "Attempting to restart unhealthy container: $container_name ($container_id)"

    if ! can_restart_container "$container_id"; then
        log_warning "Container restart in cooldown period, skipping restart"
        return 1
    fi

    if docker restart "$container_id"; then
        log_success "Successfully restarted container: $container_name"
        mark_restart_time "$container_id"
        reset_failure_count "$container_id"

        local message="Container $container_name was unhealthy and has been restarted.
Container ID: $container_id
Timestamp: $(date)
Log: $LOG_FILE"

        send_alert "Docker Container Restarted: $container_name" "$message"
        return 0
    else
        log_error "Failed to restart container: $container_name"
        return 1
    fi
}

check_container_health() {
    local container_id="$1"
    local container_name="$2"

    # Check if container is running
    local is_running
    is_running=$(get_container_state "$container_id")

    if [[ "$is_running" != "true" ]]; then
        log_error "Container not running: $container_name ($container_id)"
        increment_failure_count "$container_id"

        local failures
        failures=$(get_failure_count "$container_id")

        if [[ $failures -ge $MAX_RETRIES ]]; then
            restart_container "$container_id" "$container_name"
        fi
        return 1
    fi

    # Check health status if available
    local health_status
    health_status=$(get_container_health "$container_id")

    case "$health_status" in
        healthy)
            log_success "Container healthy: $container_name"
            reset_failure_count "$container_id"
            return 0
            ;;
        unhealthy)
            log_error "Container unhealthy: $container_name"
            increment_failure_count "$container_id"

            local failures
            failures=$(get_failure_count "$container_id")

            log_warning "Failure count for $container_name: $failures/$MAX_RETRIES"

            if [[ $failures -ge $MAX_RETRIES ]]; then
                restart_container "$container_id" "$container_name"
            fi
            return 1
            ;;
        starting)
            log_info "Container starting: $container_name"
            return 0
            ;;
        *)
            # No health check defined
            log_success "Container running (no health check): $container_name"
            reset_failure_count "$container_id"
            return 0
            ;;
    esac
}

perform_health_check() {
    log_info "Starting health check cycle..."

    local container_count=0
    local healthy_count=0
    local unhealthy_count=0

    # Get list of running containers
    while IFS=' ' read -r container_id container_name; do
        if [[ -z "$container_id" ]]; then
            continue
        fi

        ((container_count++))

        if check_container_health "$container_id" "$container_name"; then
            ((healthy_count++))
        else
            ((unhealthy_count++))
        fi
    done < <(docker ps --format "{{.ID}} {{.Names}}")

    log_info "Health check completed - Total: $container_count, Healthy: $healthy_count, Unhealthy: $unhealthy_count"

    # Send summary alert if there are unhealthy containers
    if [[ $unhealthy_count -gt 0 ]] && [[ -n "$ALERT_EMAIL" ]]; then
        local message="Docker health check summary:
Total containers: $container_count
Healthy: $healthy_count
Unhealthy: $unhealthy_count
Log: $LOG_FILE"

        send_alert "Docker Health Check Report - $unhealthy_count Unhealthy" "$message"
    fi
}

cleanup() {
    log_info "Shutting down health check monitor..."
    exit 0
}

daemonize() {
    log_info "Running as daemon..."

    while true; do
        perform_health_check
        log_info "Next check in ${CHECK_INTERVAL}s..."
        sleep "$CHECK_INTERVAL"
    done
}

################################################################################
# Main
################################################################################

main() {
    parse_arguments "$@"

    log_info "Docker Container Health Check Monitor"
    log_info "======================================"
    log_info "Check interval: ${CHECK_INTERVAL}s"
    log_info "Max retries before restart: $MAX_RETRIES"
    log_info "Log file: $LOG_FILE"

    if [[ -n "$ALERT_EMAIL" ]]; then
        log_info "Alert email: $ALERT_EMAIL"
    fi

    # Set up signal handlers
    trap cleanup SIGTERM SIGINT

    if [[ "${DAEMONIZE:-false}" == true ]]; then
        daemonize
    else
        perform_health_check
    fi
}

main "$@"
