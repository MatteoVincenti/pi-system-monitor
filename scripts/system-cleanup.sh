#!/bin/bash
# PiMonitor System Cleanup Script
# Removes old files, unused Docker resources, and optimizes the system

# Source shared libraries
TEMP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$TEMP_SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$TEMP_SCRIPT_DIR/lib/docker.sh"

# =============================================================================
# Cleanup Configuration
# =============================================================================

readonly CLEANUP_VERSION="2.0.0"

# =============================================================================
# Cleanup Functions
# =============================================================================

# Display cleanup banner
show_banner() {
    cat << 'EOF'
   ______                                
  / ____/___  ____  ____ ___  ____  ____ 
 / /   / __ \/ __ \/ __ `__ \/ __ \/ __ \
/ /___/ / / / /_/ / / / / / / /_/ / /_/ /
\____/_/ /_/\____/_/ /_/ /_/ .___/ .___/ 
                         /_/   /_/      
PiMonitor System Cleanup v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  --docker          Clean Docker resources only
  --logs            Clean log files only
  --old-files       Remove old/legacy files only
  --all             Perform complete cleanup (default)
  --dry-run         Show what would be cleaned without doing it
  -f, --force       Force cleanup without confirmation
  -h, --help        Show this help message

Examples:
  $0                # Interactive cleanup
  $0 --all -f       # Force complete cleanup
  $0 --docker       # Clean only Docker resources
  $0 --dry-run      # Preview cleanup actions
EOF
}

# Parse command line arguments
parse_args() {
    CLEAN_DOCKER="false"
    CLEAN_LOGS="false"
    CLEAN_OLD_FILES="false"
    CLEAN_ALL="true"
    DRY_RUN="false"
    FORCE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --docker)
                CLEAN_DOCKER="true"
                CLEAN_ALL="false"
                shift
                ;;
            --logs)
                CLEAN_LOGS="true"
                CLEAN_ALL="false"
                shift
                ;;
            --old-files)
                CLEAN_OLD_FILES="true"
                CLEAN_ALL="false"
                shift
                ;;
            --all)
                CLEAN_ALL="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
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
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Clean Docker resources
clean_docker_resources() {
    log_info "Cleaning Docker resources..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would clean Docker resources:"
        docker system df
        return 0
    fi
    
    # Stop PiMonitor services first
    if docker compose ps --services >/dev/null 2>&1; then
        log_info "Stopping PiMonitor services..."
        docker compose down
    fi
    
    # Clean up containers
    log_info "Removing stopped containers..."
    docker container prune -f
    
    # Clean up images
    log_info "Removing unused images..."
    docker image prune -f
    
    # Clean up networks
    log_info "Removing unused networks..."
    docker network prune -f
    
    # Clean up volumes (be careful with this)
    if [[ "$FORCE" == "true" ]] || confirm "Remove unused Docker volumes? (This may delete data)" "n"; then
        log_info "Removing unused volumes..."
        docker volume prune -f
    fi
    
    # Clean up build cache
    log_info "Removing build cache..."
    docker builder prune -f
    
    # Show space saved
    log_info "Docker cleanup completed"
    docker system df
}

# Clean log files
clean_log_files() {
    log_info "Cleaning log files..."
    
    local log_dirs=(
        "$PROJECT_ROOT/logs"
        "/var/log"
    )
    
    local cleaned_size=0
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            log_debug "Cleaning logs in: $log_dir"
            
            # Find old log files (older than 30 days)
            local old_logs
            old_logs=$(find "$log_dir" -name "*.log" -type f -mtime +30 2>/dev/null || true)
            
            if [[ -n "$old_logs" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "[DRY RUN] Would remove old log files:"
                    echo "$old_logs"
                else
                    local size_before
                    size_before=$(du -sb "$log_dir" 2>/dev/null | cut -f1 || echo "0")
                    
                    echo "$old_logs" | xargs rm -f
                    
                    local size_after
                    size_after=$(du -sb "$log_dir" 2>/dev/null | cut -f1 || echo "0")
                    
                    local saved=$((size_before - size_after))
                    cleaned_size=$((cleaned_size + saved))
                    
                    log_info "Cleaned $(echo "$old_logs" | wc -l) old log files"
                fi
            fi
            
            # Truncate large log files (larger than 100MB)
            local large_logs
            large_logs=$(find "$log_dir" -name "*.log" -type f -size +100M 2>/dev/null || true)
            
            if [[ -n "$large_logs" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "[DRY RUN] Would truncate large log files:"
                    echo "$large_logs"
                else
                    echo "$large_logs" | while read -r log_file; do
                        if [[ -f "$log_file" ]]; then
                            # Keep last 1000 lines
                            tail -n 1000 "$log_file" > "${log_file}.tmp"
                            mv "${log_file}.tmp" "$log_file"
                            log_debug "Truncated large log file: $log_file"
                        fi
                    done
                    log_info "Truncated $(echo "$large_logs" | wc -l) large log files"
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" != "true" ]] && [[ $cleaned_size -gt 0 ]]; then
        log_info "Log cleanup freed $(numfmt --to=iec $cleaned_size) of space"
    fi
}

# Remove old and legacy files
clean_old_files() {
    log_info "Removing old and legacy files..."
    
    local old_files=(
        # Legacy Docker Compose files
        "docker-compose.homarr.yaml"
        "docker-compose.portainer.yaml"
        "docker-compose.watchtower.yaml"
        
        # Old configuration files
        "configs/homarr"
        "configs/portainer"
        
        # Old script directories
        "scripts/utilities"
        
        # Temporary files
        "*.tmp"
        "*.bak"
        "*.old"
        
        # Old documentation
        "docs/old"
        "docs/legacy"
        
        # Cache directories
        ".cache"
        "tmp"
        
        # Old data directories
        "data/homarr"
        "data/portainer"
    )
    
    local removed_count=0
    
    for pattern in "${old_files[@]}"; do
        # Use find to locate files matching the pattern
        local found_files
        found_files=$(find "$PROJECT_ROOT" -name "$pattern" -type f 2>/dev/null || true)
        local found_dirs
        found_dirs=$(find "$PROJECT_ROOT" -name "$pattern" -type d 2>/dev/null || true)
        
        # Remove files
        if [[ -n "$found_files" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would remove files matching: $pattern"
                echo "$found_files"
            else
                echo "$found_files" | xargs rm -f
                local count
                count=$(echo "$found_files" | wc -l)
                removed_count=$((removed_count + count))
                log_debug "Removed $count files matching: $pattern"
            fi
        fi
        
        # Remove directories
        if [[ -n "$found_dirs" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would remove directories matching: $pattern"
                echo "$found_dirs"
            else
                echo "$found_dirs" | xargs rm -rf
                local count
                count=$(echo "$found_dirs" | wc -l)
                removed_count=$((removed_count + count))
                log_debug "Removed $count directories matching: $pattern"
            fi
        fi
    done
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Removed $removed_count old files and directories"
    fi
}

# Clean package manager caches
clean_package_caches() {
    log_info "Cleaning package manager caches..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would clean package caches"
        return 0
    fi
    
    # APT cache (Debian/Ubuntu)
    if command_exists apt-get; then
        log_debug "Cleaning APT cache..."
        sudo apt-get clean >/dev/null 2>&1 || true
        sudo apt-get autoremove -y >/dev/null 2>&1 || true
    fi
    
    # YUM/DNF cache (RHEL/Fedora)
    if command_exists yum; then
        log_debug "Cleaning YUM cache..."
        sudo yum clean all >/dev/null 2>&1 || true
    elif command_exists dnf; then
        log_debug "Cleaning DNF cache..."
        sudo dnf clean all >/dev/null 2>&1 || true
    fi
    
    # Snap cache
    if command_exists snap; then
        log_debug "Cleaning Snap cache..."
        sudo snap set system refresh.retain=2 >/dev/null 2>&1 || true
    fi
    
    log_info "Package cache cleanup completed"
}

# Clean system temporary files
clean_system_temp() {
    log_info "Cleaning system temporary files..."
    
    local temp_dirs=(
        "/tmp"
        "/var/tmp"
        "$HOME/.cache"
    )
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            # Find files older than 7 days
            local old_temp_files
            old_temp_files=$(find "$temp_dir" -type f -mtime +7 2>/dev/null || true)
            
            if [[ -n "$old_temp_files" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "[DRY RUN] Would remove old temp files from: $temp_dir"
                    echo "$old_temp_files" | head -10
                    local count
                    count=$(echo "$old_temp_files" | wc -l)
                    if [[ $count -gt 10 ]]; then
                        echo "... and $((count - 10)) more files"
                    fi
                else
                    local count
                    count=$(echo "$old_temp_files" | wc -l)
                    echo "$old_temp_files" | xargs rm -f 2>/dev/null || true
                    log_debug "Cleaned $count temporary files from: $temp_dir"
                fi
            fi
        fi
    done
}

# Generate cleanup report
generate_cleanup_report() {
    local report_file="${1:-cleanup-report.txt}"
    
    log_info "Generating cleanup report: $report_file"
    
    {
        echo "PiMonitor System Cleanup Report"
        echo "=============================="
        echo "Generated: $(date)"
        echo "Cleanup Version: $CLEANUP_VERSION"
        echo ""
        
        echo "System Information:"
        echo "------------------"
        echo "Hostname: $(hostname)"
        echo "OS: $(get_os_info)"
        echo "Architecture: $(uname -m)"
        echo ""
        
        echo "Disk Usage Before Cleanup:"
        echo "-------------------------"
        df -h
        echo ""
        
        echo "Docker System Usage:"
        echo "-------------------"
        if command_exists docker; then
            docker system df 2>/dev/null || echo "Docker not available"
        else
            echo "Docker not installed"
        fi
        echo ""
        
        echo "Memory Usage:"
        echo "------------"
        free -h
        echo ""
        
    } > "$report_file"
    
    log_info "Cleanup report saved to: $report_file"
}

# Main cleanup function
run_cleanup() {
    show_banner
    
    log_info "Starting PiMonitor system cleanup..."
    
    # Generate pre-cleanup report
    if [[ "$DRY_RUN" != "true" ]]; then
        generate_cleanup_report "pre-cleanup-report.txt"
    fi
    
    # Confirm cleanup if not forced
    if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo "This will clean up:"
        if [[ "$CLEAN_ALL" == "true" ]] || [[ "$CLEAN_DOCKER" == "true" ]]; then
            echo "  - Docker containers, images, networks, and build cache"
        fi
        if [[ "$CLEAN_ALL" == "true" ]] || [[ "$CLEAN_LOGS" == "true" ]]; then
            echo "  - Old log files (>30 days) and large log files (>100MB)"
        fi
        if [[ "$CLEAN_ALL" == "true" ]] || [[ "$CLEAN_OLD_FILES" == "true" ]]; then
            echo "  - Legacy files and temporary files"
        fi
        if [[ "$CLEAN_ALL" == "true" ]]; then
            echo "  - Package manager caches"
            echo "  - System temporary files"
        fi
        echo ""
        
        if ! confirm "Proceed with cleanup?" "y"; then
            log_info "Cleanup cancelled by user"
            return 0
        fi
    fi
    
    # Perform cleanup operations
    if [[ "$CLEAN_ALL" == "true" ]] || [[ "$CLEAN_OLD_FILES" == "true" ]]; then
        clean_old_files
        echo ""
    fi
    
    if [[ "$CLEAN_ALL" == "true" ]] || [[ "$CLEAN_LOGS" == "true" ]]; then
        clean_log_files
        echo ""
    fi
    
    if [[ "$CLEAN_ALL" == "true" ]] || [[ "$CLEAN_DOCKER" == "true" ]]; then
        clean_docker_resources
        echo ""
    fi
    
    if [[ "$CLEAN_ALL" == "true" ]]; then
        clean_package_caches
        echo ""
        
        clean_system_temp
        echo ""
    fi
    
    # Generate post-cleanup report
    if [[ "$DRY_RUN" != "true" ]]; then
        generate_cleanup_report "post-cleanup-report.txt"
        
        log_info "🎉 System cleanup completed successfully!"
        log_info "Check cleanup reports for before/after comparison"
    else
        log_info "🔍 Dry run completed - no changes were made"
        log_info "Run without --dry-run to perform actual cleanup"
    fi
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Run cleanup
    run_cleanup
}

# Run main function
main "$@"