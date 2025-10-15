#!/bin/bash
# PiMonitor Log Management Script
# Comprehensive log viewing, searching, and management utilities

# Source shared libraries
TEMP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$TEMP_SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$TEMP_SCRIPT_DIR/lib/docker.sh"

# =============================================================================
# Log Management Configuration
# =============================================================================

readonly LOGS_VERSION="2.0.0"
readonly DEFAULT_LINES=100
readonly DEFAULT_SINCE="1h"

# =============================================================================
# Log Functions
# =============================================================================

# Display logs banner
show_banner() {
    cat << 'EOF'
    __                      
   / /   ____  ____ _______ 
  / /   / __ \/ __ `/ ___/ 
 / /___/ /_/ / /_/ (__  )  
/_____/\____/\__, /____/   
            /____/         
PiMonitor Log Manager v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [service] [options]

Services:
  grafana       Show Grafana logs
  influxdb      Show InfluxDB logs
  prometheus    Show Prometheus logs
  loki          Show Loki logs
  alloy         Show Alloy logs
  telegraf      Show Telegraf logs
  all           Show logs from all services (default)

Options:
  -f, --follow          Follow log output (like tail -f)
  -n, --lines NUM       Number of lines to show (default: $DEFAULT_LINES)
  -s, --since TIME      Show logs since timestamp (e.g., 1h, 30m, 2023-01-01)
  -t, --timestamps      Show timestamps
  -l, --level LEVEL     Filter by log level (error, warn, info, debug)
  -g, --grep PATTERN    Search for pattern in logs
  -e, --errors          Show only error logs
  -w, --warnings        Show only warning and error logs
  -r, --raw             Show raw logs without formatting
  -o, --output FILE     Save logs to file
  -c, --clear           Clear service logs (requires confirmation)
  -h, --help            Show this help message

Examples:
  $0                           # Show recent logs from all services
  $0 grafana -f                # Follow Grafana logs
  $0 loki -n 500               # Show last 500 lines from Loki
  $0 all -s 1h -e              # Show errors from last hour (all services)
  $0 prometheus -g "error"     # Search for "error" in Prometheus logs
  $0 influxdb -o influx.log    # Save InfluxDB logs to file
  $0 all -l error -t           # Show all error logs with timestamps
EOF
}

# Parse command line arguments
parse_args() {
    SERVICE=""
    FOLLOW="false"
    LINES="$DEFAULT_LINES"
    SINCE="$DEFAULT_SINCE"
    TIMESTAMPS="false"
    LOG_LEVEL=""
    GREP_PATTERN=""
    ERRORS_ONLY="false"
    WARNINGS_ONLY="false"
    RAW_OUTPUT="false"
    OUTPUT_FILE=""
    CLEAR_LOGS="false"
    
    # First argument might be service name
    if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
        case "$1" in
            grafana|influxdb|prometheus|loki|alloy|telegraf|all)
                SERVICE="$1"
                shift
                ;;
        esac
    fi
    
    # Default to all services if none specified
    SERVICE="${SERVICE:-all}"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                FOLLOW="true"
                shift
                ;;
            -n|--lines)
                LINES="$2"
                shift 2
                ;;
            -s|--since)
                SINCE="$2"
                shift 2
                ;;
            -t|--timestamps)
                TIMESTAMPS="true"
                shift
                ;;
            -l|--level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            -g|--grep)
                GREP_PATTERN="$2"
                shift 2
                ;;
            -e|--errors)
                ERRORS_ONLY="true"
                shift
                ;;
            -w|--warnings)
                WARNINGS_ONLY="true"
                shift
                ;;
            -r|--raw)
                RAW_OUTPUT="true"
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -c|--clear)
                CLEAR_LOGS="true"
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
    
    # Validate arguments
    if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
        log_error "Lines must be a number: $LINES"
        exit 1
    fi
    
    if [[ -n "$LOG_LEVEL" ]] && [[ ! "$LOG_LEVEL" =~ ^(error|warn|info|debug)$ ]]; then
        log_error "Invalid log level: $LOG_LEVEL (must be: error, warn, info, debug)"
        exit 1
    fi
}

# Get Docker Compose log arguments
get_compose_args() {
    local args=("logs")
    
    # Add follow flag
    if [[ "$FOLLOW" == "true" ]]; then
        args+=("-f")
    fi
    
    # Add timestamps
    if [[ "$TIMESTAMPS" == "true" ]]; then
        args+=("-t")
    fi
    
    # Add lines limit
    args+=("--tail" "$LINES")
    
    # Add since filter
    if [[ -n "$SINCE" ]]; then
        args+=("--since" "$SINCE")
    fi
    
    echo "${args[@]}"
}

# Filter logs by level
filter_by_level() {
    local level="$1"
    
    case "$level" in
        "error")
            grep -i -E "(error|fatal|critical|exception)"
            ;;
        "warn")
            grep -i -E "(warn|warning|error|fatal|critical|exception)"
            ;;
        "info")
            grep -i -E "(info|warn|warning|error|fatal|critical|exception)"
            ;;
        "debug")
            cat  # Show all logs
            ;;
        *)
            cat  # Show all logs if no valid level
            ;;
    esac
}

# Apply grep pattern
apply_grep() {
    local pattern="$1"
    
    if [[ -n "$pattern" ]]; then
        grep -i "$pattern"
    else
        cat
    fi
}

# Format log output
format_logs() {
    if [[ "$RAW_OUTPUT" == "true" ]]; then
        cat
        return
    fi
    
    # Add colors for different log levels
    sed -E \
        -e "s/(ERROR|FATAL|CRITICAL)/$(printf '\033[31m')&$(printf '\033[0m')/gi" \
        -e "s/(WARN|WARNING)/$(printf '\033[33m')&$(printf '\033[0m')/gi" \
        -e "s/(INFO)/$(printf '\033[32m')&$(printf '\033[0m')/gi" \
        -e "s/(DEBUG|TRACE)/$(printf '\033[36m')&$(printf '\033[0m')/gi"
}

# Show logs for specific service
show_service_logs() {
    local service="$1"
    
    log_info "Showing logs for service: $service"
    
    # Check if service is running
    if ! is_service_running "$service"; then
        log_warn "Service $service is not currently running"
    fi
    
    # Get compose arguments
    local compose_args
    compose_args=$(get_compose_args)
    
    # Build command pipeline
    local cmd="docker_compose_exec $compose_args $service"
    
    # Apply filters
    if [[ "$ERRORS_ONLY" == "true" ]]; then
        cmd="$cmd | filter_by_level error"
    elif [[ "$WARNINGS_ONLY" == "true" ]]; then
        cmd="$cmd | filter_by_level warn"
    elif [[ -n "$LOG_LEVEL" ]]; then
        cmd="$cmd | filter_by_level $LOG_LEVEL"
    fi
    
    if [[ -n "$GREP_PATTERN" ]]; then
        cmd="$cmd | apply_grep '$GREP_PATTERN'"
    fi
    
    cmd="$cmd | format_logs"
    
    # Output to file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        cmd="$cmd | tee '$OUTPUT_FILE'"
        log_info "Saving logs to: $OUTPUT_FILE"
    fi
    
    # Execute command
    eval "$cmd"
}

# Show logs for all services
show_all_logs() {
    log_info "Showing logs for all services"
    
    # Get compose arguments
    local compose_args
    compose_args=$(get_compose_args)
    
    # Build command pipeline
    local cmd="docker_compose_exec $compose_args"
    
    # Apply filters
    if [[ "$ERRORS_ONLY" == "true" ]]; then
        cmd="$cmd | filter_by_level error"
    elif [[ "$WARNINGS_ONLY" == "true" ]]; then
        cmd="$cmd | filter_by_level warn"
    elif [[ -n "$LOG_LEVEL" ]]; then
        cmd="$cmd | filter_by_level $LOG_LEVEL"
    fi
    
    if [[ -n "$GREP_PATTERN" ]]; then
        cmd="$cmd | apply_grep '$GREP_PATTERN'"
    fi
    
    cmd="$cmd | format_logs"
    
    # Output to file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        cmd="$cmd | tee '$OUTPUT_FILE'"
        log_info "Saving logs to: $OUTPUT_FILE"
    fi
    
    # Execute command
    eval "$cmd"
}

# Clear service logs
clear_service_logs() {
    local service="$1"
    
    log_warn "This will clear all logs for service: $service"
    
    if ! confirm "Are you sure you want to clear the logs?" "n"; then
        log_info "Operation cancelled by user"
        return 0
    fi
    
    # Stop and remove container to clear logs
    log_info "Clearing logs for $service..."
    
    if docker_compose_exec stop "$service"; then
        docker_compose_exec rm -f "$service"
        docker_compose_exec up -d "$service"
        log_info "Logs cleared and service restarted: $service"
    else
        log_error "Failed to clear logs for $service"
        return 1
    fi
}

# Clear all service logs
clear_all_logs() {
    log_warn "This will clear all logs for ALL services"
    
    if ! confirm "Are you sure you want to clear all logs?" "n"; then
        log_info "Operation cancelled by user"
        return 0
    fi
    
    log_info "Clearing all service logs..."
    
    if docker_compose_exec down; then
        # Remove all containers to clear logs
        docker container prune -f
        
        # Restart services
        docker_compose_exec up -d
        log_info "All logs cleared and services restarted"
    else
        log_error "Failed to clear logs"
        return 1
    fi
}

# Show log statistics
show_log_stats() {
    log_info "Log Statistics"
    echo "=============="
    
    local services=("grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    printf "%-12s %-10s %-10s %-10s\n" "SERVICE" "LINES" "ERRORS" "WARNINGS"
    printf "%-12s %-10s %-10s %-10s\n" "-------" "-----" "------" "--------"
    
    for service in "${services[@]}"; do
        if is_service_running "$service"; then
            local total_lines
            total_lines=$(docker_compose_exec logs --tail 10000 "$service" 2>/dev/null | wc -l)
            
            local error_lines
            error_lines=$(docker_compose_exec logs --tail 10000 "$service" 2>/dev/null | grep -i -c -E "(error|fatal|critical)" || echo "0")
            
            local warning_lines
            warning_lines=$(docker_compose_exec logs --tail 10000 "$service" 2>/dev/null | grep -i -c -E "(warn|warning)" || echo "0")
            
            printf "%-12s %-10s %-10s %-10s\n" "$service" "$total_lines" "$error_lines" "$warning_lines"
        else
            printf "%-12s %-10s %-10s %-10s\n" "$service" "N/A" "N/A" "N/A"
        fi
    done
}

# Export logs to archive
export_logs() {
    local export_file="${1:-pimonitor-logs-$(date +%Y%m%d_%H%M%S).tar.gz}"
    local temp_dir="/tmp/pimonitor-logs-$$"
    
    log_info "Exporting logs to: $export_file"
    
    mkdir -p "$temp_dir"
    
    # Export logs from each service
    local services=("grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    for service in "${services[@]}"; do
        if is_service_running "$service"; then
            log_debug "Exporting logs for $service"
            docker_compose_exec logs --tail 10000 "$service" > "$temp_dir/${service}.log" 2>/dev/null || true
        fi
    done
    
    # Export system logs if available
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        cp -r "$PROJECT_ROOT/logs" "$temp_dir/system-logs" 2>/dev/null || true
    fi
    
    # Create archive
    if tar -czf "$export_file" -C "$temp_dir" .; then
        log_info "Logs exported successfully: $export_file"
    else
        log_error "Failed to export logs"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Monitor logs in real-time with filtering
monitor_logs() {
    log_info "Starting real-time log monitoring (press Ctrl+C to exit)"
    log_info "Filters: Level=${LOG_LEVEL:-all}, Pattern=${GREP_PATTERN:-none}"
    
    # Build monitoring command
    local cmd="docker_compose_exec logs -f --tail 0"
    
    if [[ "$SERVICE" != "all" ]]; then
        cmd="$cmd $SERVICE"
    fi
    
    # Apply filters
    if [[ "$ERRORS_ONLY" == "true" ]]; then
        cmd="$cmd | filter_by_level error"
    elif [[ "$WARNINGS_ONLY" == "true" ]]; then
        cmd="$cmd | filter_by_level warn"
    elif [[ -n "$LOG_LEVEL" ]]; then
        cmd="$cmd | filter_by_level $LOG_LEVEL"
    fi
    
    if [[ -n "$GREP_PATTERN" ]]; then
        cmd="$cmd | apply_grep '$GREP_PATTERN'"
    fi
    
    cmd="$cmd | format_logs"
    
    # Execute monitoring
    eval "$cmd"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Handle clear logs command
    if [[ "$CLEAR_LOGS" == "true" ]]; then
        show_banner
        if [[ "$SERVICE" == "all" ]]; then
            clear_all_logs
        else
            clear_service_logs "$SERVICE"
        fi
        return
    fi
    
    # Show banner for non-follow mode
    if [[ "$FOLLOW" != "true" ]]; then
        show_banner
    fi
    
    # Handle special commands
    case "$SERVICE" in
        "stats")
            show_log_stats
            return
            ;;
        "export")
            export_logs "$OUTPUT_FILE"
            return
            ;;
        "monitor")
            monitor_logs
            return
            ;;
    esac
    
    # Show logs
    if [[ "$SERVICE" == "all" ]]; then
        show_all_logs
    else
        show_service_logs "$SERVICE"
    fi
}

# Run main function
main "$@"