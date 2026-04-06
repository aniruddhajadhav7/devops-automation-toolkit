#!/bin/bash

################################################################################
# Docker Cleanup Script
# Description: Prune unused Docker containers, images, volumes, and networks
# Usage: ./docker-cleanup.sh [--all] [--dry-run]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
CLEANUP_ALL=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

show_help() {
    cat << EOF
Docker Cleanup Utility

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --all               Perform aggressive cleanup (containers, images, volumes, networks)
    --dry-run           Show what would be deleted without actually deleting it
    --help              Show this help message

EXAMPLES:
    # Remove only unused containers, images, and networks
    $0

    # Aggressive cleanup including volumes
    $0 --all

    # Show what would be removed without removing
    $0 --all --dry-run

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                CLEANUP_ALL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

get_disk_usage_before() {
    docker system df | grep -E "^(IMAGES|CONTAINERS|LOCAL VOLUMES|Build|Unused)" || true
}

cleanup_stopped_containers() {
    log_info "Cleaning up stopped containers..."

    local stopped_count
    stopped_count=$(docker ps -a -q -f "status=exited" | wc -l | xargs)

    if [[ $stopped_count -gt 0 ]]; then
        log_info "Found $stopped_count stopped containers"

        if [[ "$DRY_RUN" == true ]]; then
            docker ps -a -f "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
            log_warning "DRY RUN: Would remove $stopped_count stopped containers"
        else
            docker ps -a -q -f "status=exited" | xargs -r docker rm -v
            log_success "Removed $stopped_count stopped containers"
        fi
    else
        log_info "No stopped containers found"
    fi
}

cleanup_dangling_images() {
    log_info "Cleaning up dangling images..."

    local dangling_count
    dangling_count=$(docker images -q -f "dangling=true" | wc -l | xargs)

    if [[ $dangling_count -gt 0 ]]; then
        log_info "Found $dangling_count dangling images"

        if [[ "$DRY_RUN" == true ]]; then
            docker images -f "dangling=true" --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}"
            log_warning "DRY RUN: Would remove $dangling_count dangling images"
        else
            docker images -q -f "dangling=true" | xargs -r docker rmi
            log_success "Removed $dangling_count dangling images"
        fi
    else
        log_info "No dangling images found"
    fi
}

cleanup_unused_networks() {
    log_info "Cleaning up unused networks..."

    local unused_count
    unused_count=$(docker network ls -q -f "dangling=true" | wc -l | xargs)

    if [[ $unused_count -gt 0 ]]; then
        log_info "Found $unused_count unused networks"

        if [[ "$DRY_RUN" == true ]]; then
            docker network ls -f "dangling=true" --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}"
            log_warning "DRY RUN: Would remove $unused_count unused networks"
        else
            docker network ls -q -f "dangling=true" | xargs -r docker network rm
            log_success "Removed $unused_count unused networks"
        fi
    else
        log_info "No unused networks found"
    fi
}

cleanup_build_cache() {
    log_info "Cleaning up build cache..."

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would remove Docker build cache"
    else
        docker builder prune -f --keep-state
        log_success "Cleaned up build cache"
    fi
}

cleanup_volumes() {
    log_info "Cleaning up unused volumes..."

    local unused_vol_count
    unused_vol_count=$(docker volume ls -q -f "dangling=true" | wc -l | xargs)

    if [[ $unused_vol_count -gt 0 ]]; then
        log_info "Found $unused_vol_count unused volumes"

        if [[ "$DRY_RUN" == true ]]; then
            docker volume ls -f "dangling=true" --format "table {{.Name}}\t{{.Driver}}"
            log_warning "DRY RUN: Would remove $unused_vol_count unused volumes"
        else
            docker volume ls -q -f "dangling=true" | xargs -r docker volume rm
            log_success "Removed $unused_vol_count unused volumes"
        fi
    else
        log_info "No unused volumes found"
    fi
}

cleanup_unused_images() {
    log_info "Cleaning up unused images..."

    local unused_count
    unused_count=$(docker images -q -a --filter "dangling=false" | wc -l | xargs)

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would prune all unused images"
    else
        docker image prune -a -f --filter "until=720h"
        log_success "Pruned unused images older than 30 days"
    fi
}

full_system_prune() {
    log_info "Performing full system prune..."

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN: Would perform full Docker system prune"
    else
        docker system prune -a -f --volumes
        log_success "Full system prune completed"
    fi
}

show_disk_usage() {
    log_info "Docker disk usage:"
    docker system df
}

################################################################################
# Main
################################################################################

main() {
    parse_arguments "$@"

    log_info "Docker Cleanup Utility"
    log_info "======================"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
    fi

    echo ""
    log_info "Before cleanup:"
    get_disk_usage_before
    echo ""

    if [[ "$CLEANUP_ALL" == true ]]; then
        log_info "Running aggressive cleanup..."
        cleanup_stopped_containers
        cleanup_dangling_images
        cleanup_unused_networks
        cleanup_volumes
        cleanup_unused_images
        cleanup_build_cache
    else
        log_info "Running standard cleanup..."
        cleanup_stopped_containers
        cleanup_dangling_images
        cleanup_unused_networks
        cleanup_build_cache
    fi

    echo ""
    log_info "After cleanup:"
    show_disk_usage

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN complete - no changes were made"
    else
        log_success "Cleanup completed successfully"
    fi
}

main "$@"
