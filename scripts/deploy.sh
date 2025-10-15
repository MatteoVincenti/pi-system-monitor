#!/bin/bash
# PiMonitor Deployment Management Script
# Comprehensive deployment management with environment selection and health monitoring

# Source shared libraries
DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$DEPLOY_SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$DEPLOY_SCRIPT_DIR/lib/docker.sh"
# shellcheck source=./lib/validation.sh
source "$DEPLOY_SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# Deployment Configuration
# =============================================================================

readonly DEPLOY_VERSION="2.0.0"
readonly CONFIG_FILE="$PROJECT_ROOT/.pimonitor-config"

# Load deployment configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log_debug "Loaded configuration from $CONFIG_FILE"
    else
        log_warn "No configuration file found, using defaults"
        export ENVIRONMENT="development"
        export INCLUDE_OPTIONAL="false"
    fi
}

# =============================================================================
# Deployment Functions
# =============================================================================

# Display deployment banner
show_banner() {
    cat << 'EOF'
    ____  _ __  __            _ __            
   / __ \(_) /_/ /_____  ____(_) /_____  _____
  / /_/ / / __/ __/ __ \/ ___/ / __/ __ \/ ___/
 / ____/ / /_/ /_/ /_/ / /  / / /_/ /_/ / /    
/_/   /_/\__/\__/\____/_/  /_/\__/\____/_/     
                                               
PiMonitor Deployment Manager v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  start     Start PiMonitor services
  stop      Stop PiMonitor services
  restart   Restart PiMonitor services
  status    Show service status
  logs      Show service logs
  update    Update images and restart services
  backup    Backup service data
  restore   Restore service data from backup
  validate  Validate configuration and environment
  config    Show current configuration
  clean     Clean up unused Docker resources

Options:
  -e, --environment ENV    Set environment (development|production)
  -o, --optional          Include optional services
  -f, --force             Force operation without confirmation
  -h, --help              Show this help message

Examples:
  $0 start                    # Start with current configuration
  $0 start -e production      # Start in production mode
  $0 start -o                 # Start with optional services
  $0 stop -f                  # Stop without confirmation
  $0 logs grafana             # Show Grafana logs
  $0 backup                   # Backup all data
EOF
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    SERVICE=""
    FORCE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|restart|status|logs|update|backup|restore|validate|config|clean)
                COMMAND="$1"
                shift
                ;;
            -e|--environment)
                export ENVIRONMENT="$2"
                shift 2
                ;;
            -o|--optional)
                export INCLUDE_OPTIONAL="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [[ -z "$SERVICE" ]] && [[ "$COMMAND" == "logs" ]]; then
                    SERVICE="$1"
                else
                    log_error "Unknown argument: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        log_error "No command specified"
        show_usage
        exit 1
    fi
}

# Validate deployment prerequisites
validate_deployment() {
    log_info "Validating deployment prerequisites..."
    
    # Check if setup was completed
    if [[ ! -f "$PROJECT_ROOT/.pimonitor-setup-complete" ]]; then
        log_error "PiMonitor setup not completed. Run './scripts/setup.sh' first."
        exit 1
    fi
    
    # Validate Docker
    if ! validate_docker || ! validate_docker_compose; then
        log_error "Docker validation failed"
        exit 1
    fi
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        exit 1
    fi
    
    log_info "Deployment validation completed"
}

# Start services
start_services() {
    log_info "Starting PiMonitor services..."
    log_info "Environment: ${ENVIRONMENT:-development}"
    log_info "Optional services: ${INCLUDE_OPTIONAL:-false}"
    
    # Ensure network exists
    ensure_docker_network "$DOCKER_NETWORK"
    
    # Pull latest images if in production
    if [[ "${ENVIRONMENT:-development}" == "production" ]]; then
        log_info "Pulling latest images for production deployment..."
        if ! docker_compose_exec pull; then
            log_warn "Failed to pull some images, continuing with existing images"
        fi
    fi
    
    # Start services
    if ! docker_compose_exec up -d; then
        log_error "Failed to start services"
        return 1
    fi
    
    # Wait for core services to be healthy
    log_info "Waiting for services to become healthy..."
    local core_services=("loki" "influxdb" "prometheus" "grafana")
    local failed_services=()
    
    for service in "${core_services[@]}"; do
        if ! wait_for_service_health "$service" 120; then
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        log_warn "Some services failed to become healthy: ${failed_services[*]}"
        log_warn "Check service logs for details"
    else
        log_info "All core services are healthy"
    fi
    
    # Show service URLs
    show_service_urls
    
    log_info "Services started successfully"
}

# Stop services
stop_services() {
    log_info "Stopping PiMonitor services..."
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "Are you sure you want to stop all services?" "n"; then
            log_info "Operation cancelled by user"
            return 0
        fi
    fi
    
    if ! docker_compose_exec down; then
        log_error "Failed to stop services"
        return 1
    fi
    
    log_info "Services stopped successfully"
}

# Restart services
restart_services() {
    log_info "Restarting PiMonitor services..."
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "Are you sure you want to restart all services?" "n"; then
            log_info "Operation cancelled by user"
            return 0
        fi
    fi
    
    stop_services
    sleep 5
    start_services
}

# Show service status
show_status() {
    log_info "PiMonitor Service Status"
    echo "========================"
    
    # Show Docker Compose status
    docker_compose_exec ps
    
    echo ""
    echo "Service Health:"
    echo "---------------"
    
    local services=("grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    for service in "${services[@]}"; do
        local health_status
        health_status=$(check_service_health "$service")
        
        local status_color=""
        case "$health_status" in
            "healthy"|"no_healthcheck") status_color="$GREEN" ;;
            "starting") status_color="$YELLOW" ;;
            "unhealthy") status_color="$RED" ;;
            "not_running") status_color="$RED" ;;
        esac
        
        printf "%-12s: %b%s%b\n" "$service" "$status_color" "$health_status" "$NC"
    done
    
    echo ""
    echo "System Resources:"
    echo "-----------------"
    echo "Memory Usage: $(get_memory_usage)%"
    echo "Disk Usage: $(get_disk_usage)%"
    echo "Load Average: $(get_system_load)"
    
    # Show service URLs if services are running
    if docker_compose_exec ps --services --filter "status=running" | grep -q .; then
        echo ""
        show_service_urls
    fi
}

# Show service URLs
show_service_urls() {
    echo "Service URLs:"
    echo "-------------"
    echo "Grafana:    http://localhost:${GRAFANA_PORT:-3000}"
    echo "Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "InfluxDB:   http://localhost:${INFLUXDB_PORT:-8086}"
    echo "Loki:       http://localhost:${LOKI_PORT:-3100}"
    echo "Alloy:      http://localhost:${ALLOY_PORT:-12345}"
    
    if [[ "${INCLUDE_OPTIONAL:-false}" == "true" ]]; then
        echo "Portainer:  https://localhost:9443"
    fi
}

# Show service logs
show_logs() {
    local service="${SERVICE:-}"
    local follow="true"
    local lines="100"
    
    if [[ -n "$service" ]]; then
        log_info "Showing logs for service: $service"
        get_service_logs "$service" "$lines" "$follow"
    else
        log_info "Showing logs for all services (press Ctrl+C to exit)"
        docker_compose_exec logs -f --tail "$lines"
    fi
}

# Update services
update_services() {
    log_info "Updating PiMonitor services..."
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "This will pull new images and restart services. Continue?" "y"; then
            log_info "Update cancelled by user"
            return 0
        fi
    fi
    
    # Backup data before update
    log_info "Creating backup before update..."
    backup_data "pre-update"
    
    # Update images and restart
    if ! update_services "true"; then
        log_error "Update failed"
        return 1
    fi
    
    log_info "Update completed successfully"
}

# Backup service data
backup_data() {
    local backup_name="${1:-manual-$(date +%Y%m%d_%H%M%S)}"
    local backup_dir="$PROJECT_ROOT/backups/$backup_name"
    
    log_info "Creating backup: $backup_name"
    mkdir -p "$backup_dir"
    
    # Backup volumes
    log_info "Backing up Docker volumes..."
    local volumes
    volumes=$(list_project_volumes)
    
    for volume in $volumes; do
        backup_volume "$volume" "$backup_dir/volumes"
    done
    
    # Backup configurations
    log_info "Backing up configurations..."
    cp -r "$PROJECT_ROOT/configs" "$backup_dir/"
    cp "$PROJECT_ROOT/.env" "$backup_dir/" 2>/dev/null || true
    cp "$CONFIG_FILE" "$backup_dir/" 2>/dev/null || true
    
    # Create backup manifest
    {
        echo "PiMonitor Backup Manifest"
        echo "========================"
        echo "Created: $(date)"
        echo "Version: $DEPLOY_VERSION"
        echo "Environment: ${ENVIRONMENT:-development}"
        echo "Optional Services: ${INCLUDE_OPTIONAL:-false}"
        echo ""
        echo "Volumes:"
        echo "$volumes"
    } > "$backup_dir/manifest.txt"
    
    log_info "Backup completed: $backup_dir"
}

# Restore service data
restore_data() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name required for restore"
        echo "Available backups:"
        ls -1 "$PROJECT_ROOT/backups/" 2>/dev/null || echo "No backups found"
        return 1
    fi
    
    local backup_dir="$PROJECT_ROOT/backups/$backup_name"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup not found: $backup_dir"
        return 1
    fi
    
    log_warn "This will restore data from backup: $backup_name"
    log_warn "Current data will be overwritten!"
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "Are you sure you want to continue?" "n"; then
            log_info "Restore cancelled by user"
            return 0
        fi
    fi
    
    # Stop services first
    log_info "Stopping services for restore..."
    docker_compose_exec down
    
    # Restore volumes
    log_info "Restoring Docker volumes..."
    find "$backup_dir/volumes" -name "*.tar.gz" -type f | while read -r backup_file; do
        local volume_name
        volume_name=$(basename "$backup_file" .tar.gz | sed 's/_[0-9]*_[0-9]*$//')
        restore_volume "$volume_name" "$backup_file"
    done
    
    # Restore configurations
    if [[ -d "$backup_dir/configs" ]]; then
        log_info "Restoring configurations..."
        cp -r "$backup_dir/configs"/* "$PROJECT_ROOT/configs/"
    fi
    
    if [[ -f "$backup_dir/.env" ]]; then
        log_info "Restoring environment configuration..."
        cp "$backup_dir/.env" "$PROJECT_ROOT/"
    fi
    
    log_info "Restore completed. Starting services..."
    start_services
}

# Clean up Docker resources
clean_resources() {
    log_info "Cleaning up Docker resources..."
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "This will remove unused Docker images, containers, and networks. Continue?" "y"; then
            log_info "Cleanup cancelled by user"
            return 0
        fi
    fi
    
    docker_cleanup "false"
    
    log_info "Cleanup completed"
}

# Show current configuration
show_config() {
    log_info "Current PiMonitor Configuration"
    echo "==============================="
    echo "Environment: ${ENVIRONMENT:-development}"
    echo "Optional Services: ${INCLUDE_OPTIONAL:-false}"
    echo "Project Root: $PROJECT_ROOT"
    echo "Docker Network: $DOCKER_NETWORK"
    echo ""
    
    echo "Service Ports:"
    echo "  Grafana: ${GRAFANA_PORT:-3000}"
    echo "  InfluxDB: ${INFLUXDB_PORT:-8086}"
    echo "  Prometheus: ${PROMETHEUS_PORT:-9090}"
    echo "  Loki: ${LOKI_PORT:-3100}"
    echo "  Alloy: ${ALLOY_PORT:-12345}"
    echo ""
    
    echo "Compose Files:"
    local compose_files
    compose_files=$(get_compose_files "${ENVIRONMENT:-development}" "${INCLUDE_OPTIONAL:-false}")
    echo "$compose_files" | tr ' ' '\n' | grep -v '^-f$'
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Load configuration
    load_config
    
    # Show banner for interactive commands
    if [[ "$COMMAND" != "logs" ]]; then
        show_banner
    fi
    
    # Execute command
    case "$COMMAND" in
        "start")
            validate_deployment
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            validate_deployment
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "update")
            validate_deployment
            update_services
            ;;
        "backup")
            backup_data "$2"
            ;;
        "restore")
            restore_data "$2"
            ;;
        "validate")
            validate_all
            ;;
        "config")
            show_config
            ;;
        "clean")
            clean_resources
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"