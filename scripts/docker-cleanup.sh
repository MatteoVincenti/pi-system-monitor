#!/bin/bash
# Enhanced Docker Cleanup Script for PiMonitor
# Comprehensive Docker resource cleanup with safety checks and reporting

# Source shared libraries
TEMP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$TEMP_SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$TEMP_SCRIPT_DIR/lib/docker.sh"

# =============================================================================
# Docker Cleanup Configuration
# =============================================================================

readonly CLEANUP_VERSION="2.0.0"

# =============================================================================
# Cleanup Functions
# =============================================================================

# Display cleanup banner
show_banner() {
    cat << 'EOF'
    ____             __                
   / __ \____  _____/ /_____  _____   
  / / / / __ \/ ___/ //_/ _ \/ ___/   
 / /_/ / /_/ / /__/ ,< /  __/ /       
/_____/\____/\___/_/|_|\___/_/        
                                      
PiMonitor Docker Cleanup v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -a, --aggressive     Aggressive cleanup (includes volumes and build cache)
  -s, --safe          Safe cleanup (containers and images only)
  -d, --dry-run       Show what would be cleaned without actually doing it
  -f, --force         Force cleanup without confirmation
  -r, --report        Generate cleanup report
  -v, --verbose       Verbose output
  -h, --help          Show this help message

Cleanup Levels:
  Safe Mode:          Removes stopped containers and unused images
  Normal Mode:        Adds unused networks and dangling volumes
  Aggressive Mode:    Includes all unused volumes and build cache

Examples:
  $0                  # Normal cleanup with confirmation
  $0 -a -f           # Aggressive cleanup without confirmation
  $0 -d              # Dry run to see what would be cleaned
  $0 -s -r           # Safe cleanup with report generation
EOF
}

# Parse command line arguments
parse_args() {
    CLEANUP_MODE="normal"
    DRY_RUN="false"
    FORCE="false"
    GENERATE_REPORT="false"
    VERBOSE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--aggressive)
                CLEANUP_MODE="aggressive"
                shift
                ;;
            -s|--safe)
                CLEANUP_MODE="safe"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -r|--report)
                GENERATE_REPORT="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                export LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Get Docker resource statistics before cleanup
get_docker_stats_before() {
    log_info "Collecting Docker resource statistics..."
    
    # Get current statistics
    CONTAINERS_BEFORE=$(docker ps -aq | wc -l)
    IMAGES_BEFORE=$(docker images -q | wc -l)
    VOLUMES_BEFORE=$(docker volume ls -q | wc -l)
    NETWORKS_BEFORE=$(docker network ls -q | wc -l)
    
    # Get disk usage
    DISK_USAGE_BEFORE=$(docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}")
    
    log_debug "Resources before cleanup:"
    log_debug "  Containers: $CONTAINERS_BEFORE"
    log_debug "  Images: $IMAGES_BEFORE"
    log_debug "  Volumes: $VOLUMES_BEFORE"
    log_debug "  Networks: $NETWORKS_BEFORE"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Docker Disk Usage Before Cleanup:"
        echo "$DISK_USAGE_BEFORE"
        echo ""
    fi
}

# Get Docker resource statistics after cleanup
get_docker_stats_after() {
    log_info "Collecting post-cleanup statistics..."
    
    # Get current statistics
    CONTAINERS_AFTER=$(docker ps -aq | wc -l)
    IMAGES_AFTER=$(docker images -q | wc -l)
    VOLUMES_AFTER=$(docker volume ls -q | wc -l)
    NETWORKS_AFTER=$(docker network ls -q | wc -l)
    
    # Get disk usage
    DISK_USAGE_AFTER=$(docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}")
    
    # Calculate differences
    CONTAINERS_REMOVED=$((CONTAINERS_BEFORE - CONTAINERS_AFTER))
    IMAGES_REMOVED=$((IMAGES_BEFORE - IMAGES_AFTER))
    VOLUMES_REMOVED=$((VOLUMES_BEFORE - VOLUMES_AFTER))
    NETWORKS_REMOVED=$((NETWORKS_BEFORE - NETWORKS_AFTER))
    
    log_info "Cleanup Summary:"
    log_info "  Containers removed: $CONTAINERS_REMOVED"
    log_info "  Images removed: $IMAGES_REMOVED"
    log_info "  Volumes removed: $VOLUMES_REMOVED"
    log_info "  Networks removed: $NETWORKS_REMOVED"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo "Docker Disk Usage After Cleanup:"
        echo "$DISK_USAGE_AFTER"
    fi
}

# Check if PiMonitor services are running
check_pimonitor_services() {
    log_info "Checking PiMonitor service status..."
    
    local running_services=()
    local pimonitor_services=("grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    for service in "${pimonitor_services[@]}"; do
        if is_service_running "$service"; then
            running_services+=("$service")
        fi
    done
    
    if [[ ${#running_services[@]} -gt 0 ]]; then
        log_warn "PiMonitor services are currently running: ${running_services[*]}"
        log_warn "Cleanup will not affect running services, but may remove unused resources"
        
        if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
            if ! confirm "Continue with cleanup while services are running?" "y"; then
                log_info "Cleanup cancelled by user"
                exit 0
            fi
        fi
    else
        log_info "No PiMonitor services are currently running"
    fi
}

# Perform dry run analysis
perform_dry_run() {
    log_info "Performing dry run analysis..."
    
    echo "=== DRY RUN: What would be cleaned ==="
    echo ""
    
    # Stopped containers
    local stopped_containers
    stopped_containers=$(docker ps -aq --filter "status=exited" --filter "status=created" 2>/dev/null | wc -l)
    echo "Stopped containers to remove: $stopped_containers"
    
    # Unused images
    local unused_images
    if [[ "$CLEANUP_MODE" == "aggressive" ]]; then
        unused_images=$(docker images -q --filter "dangling=false" 2>/dev/null | wc -l)
        echo "All unused images to remove: $unused_images"
    else
        unused_images=$(docker images -q --filter "dangling=true" 2>/dev/null | wc -l)
        echo "Dangling images to remove: $unused_images"
    fi
    
    # Unused volumes
    if [[ "$CLEANUP_MODE" != "safe" ]]; then
        local unused_volumes
        unused_volumes=$(docker volume ls -q --filter "dangling=true" 2>/dev/null | wc -l)
        echo "Unused volumes to remove: $unused_volumes"
    fi
    
    # Unused networks
    if [[ "$CLEANUP_MODE" != "safe" ]]; then
        local unused_networks
        unused_networks=$(docker network ls -q --filter "dangling=true" 2>/dev/null | wc -l)
        echo "Unused networks to remove: $unused_networks"
    fi
    
    # Build cache
    if [[ "$CLEANUP_MODE" == "aggressive" ]]; then
        echo "Build cache: Will be completely cleared"
    fi
    
    echo ""
    echo "Current disk usage:"
    docker system df
    
    echo ""
    log_info "Dry run completed. Use --force to perform actual cleanup."
}

# Safe cleanup mode
perform_safe_cleanup() {
    log_info "Performing safe cleanup (containers and dangling images only)..."
    
    # Remove stopped containers
    log_info "Removing stopped containers..."
    if docker container prune -f; then
        log_info "Stopped containers removed successfully"
    else
        log_warn "Some containers could not be removed"
    fi
    
    # Remove dangling images only
    log_info "Removing dangling images..."
    if docker image prune -f; then
        log_info "Dangling images removed successfully"
    else
        log_warn "Some dangling images could not be removed"
    fi
}

# Normal cleanup mode
perform_normal_cleanup() {
    log_info "Performing normal cleanup (containers, images, networks, dangling volumes)..."
    
    # Remove stopped containers, unused networks, and dangling images/volumes
    log_info "Removing unused Docker resources..."
    if docker system prune -f; then
        log_info "System prune completed successfully"
    else
        log_warn "System prune encountered some issues"
    fi
    
    # Additional network cleanup
    log_info "Cleaning up unused networks..."
    if docker network prune -f; then
        log_info "Network cleanup completed"
    else
        log_warn "Network cleanup encountered issues"
    fi
}

# Aggressive cleanup mode
perform_aggressive_cleanup() {
    log_info "Performing aggressive cleanup (all unused resources including volumes and build cache)..."
    
    # Remove all unused resources including volumes
    log_info "Removing all unused Docker resources..."
    if docker system prune --all --volumes -f; then
        log_info "Aggressive system prune completed successfully"
    else
        log_warn "Aggressive system prune encountered some issues"
    fi
    
    # Clean up build cache
    log_info "Cleaning up Docker build cache..."
    if docker builder prune --all -f; then
        log_info "Build cache cleanup completed"
    else
        log_warn "Build cache cleanup encountered issues"
    fi
    
    # Additional cleanup for any remaining resources
    log_info "Performing additional resource cleanup..."
    docker volume prune -f 2>/dev/null || log_warn "Volume prune had issues"
    docker image prune --all -f 2>/dev/null || log_warn "Image prune had issues"
    docker network prune -f 2>/dev/null || log_warn "Network prune had issues"
}

# Generate cleanup report
generate_cleanup_report() {
    local report_file="$PROJECT_ROOT/logs/docker-cleanup-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating cleanup report: $report_file"
    
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "PiMonitor Docker Cleanup Report"
        echo "==============================="
        echo "Date: $(date)"
        echo "Cleanup Mode: $CLEANUP_MODE"
        echo "Version: $CLEANUP_VERSION"
        echo ""
        
        echo "Resources Before Cleanup:"
        echo "  Containers: $CONTAINERS_BEFORE"
        echo "  Images: $IMAGES_BEFORE"
        echo "  Volumes: $VOLUMES_BEFORE"
        echo "  Networks: $NETWORKS_BEFORE"
        echo ""
        
        echo "Resources After Cleanup:"
        echo "  Containers: $CONTAINERS_AFTER"
        echo "  Images: $IMAGES_AFTER"
        echo "  Volumes: $VOLUMES_AFTER"
        echo "  Networks: $NETWORKS_AFTER"
        echo ""
        
        echo "Resources Removed:"
        echo "  Containers: $CONTAINERS_REMOVED"
        echo "  Images: $IMAGES_REMOVED"
        echo "  Volumes: $VOLUMES_REMOVED"
        echo "  Networks: $NETWORKS_REMOVED"
        echo ""
        
        echo "Disk Usage Before:"
        echo "$DISK_USAGE_BEFORE"
        echo ""
        
        echo "Disk Usage After:"
        echo "$DISK_USAGE_AFTER"
        
    } > "$report_file"
    
    log_info "Cleanup report saved to: $report_file"
}

# Validate Docker environment
validate_docker_environment() {
    log_info "Validating Docker environment..."
    
    if ! validate_docker; then
        log_error "Docker validation failed"
        exit 1
    fi
    
    if ! validate_docker_compose; then
        log_error "Docker Compose validation failed"
        exit 1
    fi
    
    log_info "Docker environment validation passed"
}

# Main cleanup function
perform_cleanup() {
    # Validate Docker environment
    validate_docker_environment
    
    # Check PiMonitor services
    check_pimonitor_services
    
    # Get statistics before cleanup
    get_docker_stats_before
    
    # Perform dry run if requested
    if [[ "$DRY_RUN" == "true" ]]; then
        perform_dry_run
        return 0
    fi
    
    # Confirm cleanup if not forced
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        log_warn "This will remove unused Docker resources in $CLEANUP_MODE mode"
        if ! confirm "Are you sure you want to continue?" "n"; then
            log_info "Cleanup cancelled by user"
            return 0
        fi
    fi
    
    # Perform cleanup based on mode
    case "$CLEANUP_MODE" in
        "safe")
            perform_safe_cleanup
            ;;
        "normal")
            perform_normal_cleanup
            ;;
        "aggressive")
            perform_aggressive_cleanup
            ;;
        *)
            log_error "Unknown cleanup mode: $CLEANUP_MODE"
            return 1
            ;;
    esac
    
    # Get statistics after cleanup
    get_docker_stats_after
    
    # Generate report if requested
    if [[ "$GENERATE_REPORT" == "true" ]]; then
        generate_cleanup_report
    fi
    
    log_info "Docker cleanup completed successfully!"
}

# Cleanup function for script exit
cleanup() {
    log_info "Docker cleanup script finished"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Show banner
    show_banner
    
    # Create necessary directories
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Perform cleanup
    perform_cleanup
}

# Run main function
main "$@"