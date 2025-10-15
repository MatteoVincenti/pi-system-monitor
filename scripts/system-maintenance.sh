#!/bin/bash
# Enhanced System Maintenance Script for PiMonitor
# Comprehensive system updates, cleanup, and maintenance for Raspberry Pi

# Source shared libraries
TEMP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$TEMP_SCRIPT_DIR/lib/common.sh"

# =============================================================================
# System Maintenance Configuration
# =============================================================================

readonly MAINTENANCE_VERSION="2.0.0"

# =============================================================================
# Maintenance Functions
# =============================================================================

# Display maintenance banner
show_banner() {
    cat << 'EOF'
   _____            __                
  / ___/__  _______/ /____  ____ ___  
  \__ \/ / / / ___/ __/ _ \/ __ `__ \ 
 ___/ / /_/ (__  ) /_/  __/ / / / / / 
/____/\__, /____/\__/\___/_/ /_/ /_/  
     /____/                          
PiMonitor System Maintenance v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -u, --update-only    Only perform system updates (no cleanup)
  -c, --clean-only     Only perform system cleanup (no updates)
  -f, --force          Force operations without confirmation
  -r, --reboot         Reboot system after maintenance (if needed)
  -d, --dry-run        Show what would be done without executing
  -v, --verbose        Verbose output
  -h, --help           Show this help message

Maintenance Tasks:
  System Updates:      Update package lists, upgrade packages, dist-upgrade
  System Cleanup:      Remove unnecessary packages, clean package cache
  Log Cleanup:         Rotate and clean system logs
  Temp Cleanup:        Clean temporary files and directories
  Docker Maintenance:  Clean Docker resources (if Docker is installed)

Examples:
  $0                   # Full maintenance with confirmation
  $0 -f -r            # Full maintenance with auto-reboot
  $0 -u               # Updates only
  $0 -c -f            # Cleanup only without confirmation
  $0 -d               # Dry run to see what would be done
EOF
}

# Parse command line arguments
parse_args() {
    UPDATE_ONLY="false"
    CLEAN_ONLY="false"
    FORCE="false"
    AUTO_REBOOT="false"
    DRY_RUN="false"
    VERBOSE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--update-only)
                UPDATE_ONLY="true"
                shift
                ;;
            -c|--clean-only)
                CLEAN_ONLY="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -r|--reboot)
                AUTO_REBOOT="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
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

# Check system requirements and permissions
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check if running on supported OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine operating system"
        return 1
    fi
    
    # Check for required commands
    local required_commands=("apt" "systemctl" "df" "du")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command not found: $cmd"
            return 1
        fi
    done
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_warn "This script requires sudo access for system maintenance"
        if [[ "$FORCE" != "true" ]]; then
            if ! confirm "Continue with sudo access?" "y"; then
                log_info "Maintenance cancelled by user"
                exit 0
            fi
        fi
    fi
    
    log_info "System requirements check passed"
}

# Get system information
get_system_info() {
    log_info "Gathering system information..."
    
    # OS information
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        SYSTEM_OS="${NAME:-Unknown} ${VERSION:-Unknown}"
    else
        SYSTEM_OS=$(uname -s)
    fi
    
    # System resources
    SYSTEM_MEMORY=$(free -h | awk 'NR==2{print $2}')
    SYSTEM_DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')
    SYSTEM_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    
    log_debug "System: $SYSTEM_OS"
    log_debug "Memory: $SYSTEM_MEMORY"
    log_debug "Disk Usage: $SYSTEM_DISK_USAGE"
    log_debug "Load Average: $SYSTEM_LOAD"
}

# Check if reboot is required
check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        REBOOT_REQUIRED="true"
        log_warn "System reboot is required"
        
        if [[ -f /var/run/reboot-required.pkgs ]]; then
            log_debug "Packages requiring reboot:"
            while read -r pkg; do
                log_debug "  - $pkg"
            done < /var/run/reboot-required.pkgs
        fi
    else
        REBOOT_REQUIRED="false"
        log_debug "No reboot required"
    fi
}

# Perform system updates
perform_system_updates() {
    log_info "Performing system updates..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update package lists"
        log_info "[DRY RUN] Would upgrade installed packages"
        log_info "[DRY RUN] Would perform distribution upgrade"
        log_info "[DRY RUN] Would fix broken dependencies"
        return 0
    fi
    
    # Update package lists
    log_info "Updating package lists..."
    if sudo apt update -y; then
        log_info "Package lists updated successfully"
    else
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Check for available upgrades
    local upgradable_packages
    upgradable_packages=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    log_info "Found $upgradable_packages packages to upgrade"
    
    if [[ $upgradable_packages -gt 0 ]]; then
        # Upgrade installed packages
        log_info "Upgrading installed packages..."
        if sudo apt full-upgrade -y; then
            log_info "Package upgrade completed successfully"
        else
            log_warn "Package upgrade encountered some issues"
        fi
        
        # Perform distribution upgrade
        log_info "Performing distribution upgrade..."
        if sudo apt dist-upgrade -y; then
            log_info "Distribution upgrade completed successfully"
        else
            log_warn "Distribution upgrade encountered some issues"
        fi
        
        # Fix broken dependencies
        log_info "Fixing broken dependencies..."
        if sudo apt --fix-broken --fix-missing install -y; then
            log_info "Dependency fixes completed successfully"
        else
            log_warn "Dependency fixes encountered some issues"
        fi
    else
        log_info "System is already up to date"
    fi
}

# Perform system cleanup
perform_system_cleanup() {
    log_info "Performing system cleanup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would remove unnecessary packages"
        log_info "[DRY RUN] Would clean package cache"
        log_info "[DRY RUN] Would clean temporary files"
        log_info "[DRY RUN] Would rotate system logs"
        return 0
    fi
    
    # Remove unnecessary packages
    log_info "Removing unnecessary packages..."
    if sudo apt autoremove --purge -y; then
        log_info "Unnecessary packages removed successfully"
    else
        log_warn "Package removal encountered some issues"
    fi
    
    # Clean package cache
    log_info "Cleaning package cache..."
    if sudo apt autoclean -y && sudo apt clean -y; then
        log_info "Package cache cleaned successfully"
    else
        log_warn "Package cache cleanup encountered some issues"
    fi
    
    # Clean temporary files
    clean_temporary_files
    
    # Rotate and clean logs
    clean_system_logs
    
    # Clean user cache (if safe to do so)
    clean_user_cache
}

# Clean temporary files
clean_temporary_files() {
    log_info "Cleaning temporary files..."
    
    local temp_dirs=("/tmp" "/var/tmp")
    local cleaned_size=0
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            # Get size before cleanup
            local size_before
            size_before=$(du -sb "$temp_dir" 2>/dev/null | cut -f1 || echo "0")
            
            # Clean files older than 7 days
            if sudo find "$temp_dir" -type f -atime +7 -delete 2>/dev/null; then
                local size_after
                size_after=$(du -sb "$temp_dir" 2>/dev/null | cut -f1 || echo "0")
                local size_diff=$((size_before - size_after))
                cleaned_size=$((cleaned_size + size_diff))
                
                log_debug "Cleaned $temp_dir: $(numfmt --to=iec $size_diff) freed"
            fi
        fi
    done
    
    if [[ $cleaned_size -gt 0 ]]; then
        log_info "Temporary files cleanup freed $(numfmt --to=iec $cleaned_size)"
    else
        log_info "No temporary files to clean"
    fi
}

# Clean system logs
clean_system_logs() {
    log_info "Cleaning system logs..."
    
    # Rotate logs using logrotate
    if command_exists logrotate; then
        if sudo logrotate -f /etc/logrotate.conf 2>/dev/null; then
            log_info "Log rotation completed successfully"
        else
            log_warn "Log rotation encountered some issues"
        fi
    fi
    
    # Clean journald logs (keep last 7 days)
    if command_exists journalctl; then
        if sudo journalctl --vacuum-time=7d 2>/dev/null; then
            log_info "Journald logs cleaned successfully"
        else
            log_warn "Journald log cleanup encountered some issues"
        fi
    fi
    
    # Clean old log files in /var/log
    if sudo find /var/log -name "*.log.*" -type f -mtime +30 -delete 2>/dev/null; then
        log_info "Old log files cleaned successfully"
    fi
}

# Clean user cache directories
clean_user_cache() {
    log_info "Cleaning user cache directories..."
    
    local cache_dirs=(
        "$HOME/.cache"
        "$HOME/.local/share/Trash"
    )
    
    local cleaned_size=0
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            # Get size before cleanup
            local size_before
            size_before=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
            
            # Clean cache files older than 30 days
            if find "$cache_dir" -type f -atime +30 -delete 2>/dev/null; then
                local size_after
                size_after=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
                local size_diff=$((size_before - size_after))
                cleaned_size=$((cleaned_size + size_diff))
                
                log_debug "Cleaned $cache_dir: $(numfmt --to=iec $size_diff) freed"
            fi
        fi
    done
    
    if [[ $cleaned_size -gt 0 ]]; then
        log_info "User cache cleanup freed $(numfmt --to=iec $cleaned_size)"
    else
        log_info "No user cache to clean"
    fi
}

# Perform Docker maintenance (if Docker is installed)
perform_docker_maintenance() {
    if command_exists docker; then
        log_info "Docker detected, performing Docker maintenance..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would clean Docker resources"
            return 0
        fi
        
        # Use our enhanced Docker cleanup script if available
        if [[ -f "$SCRIPT_DIR/docker-cleanup.sh" ]]; then
            log_info "Running Docker cleanup..."
            if "$SCRIPT_DIR/docker-cleanup.sh" --safe --force; then
                log_info "Docker cleanup completed successfully"
            else
                log_warn "Docker cleanup encountered some issues"
            fi
        else
            # Fallback to basic Docker cleanup
            log_info "Running basic Docker cleanup..."
            if docker system prune -f 2>/dev/null; then
                log_info "Basic Docker cleanup completed"
            else
                log_warn "Docker cleanup encountered issues"
            fi
        fi
    else
        log_debug "Docker not installed, skipping Docker maintenance"
    fi
}

# Generate maintenance report
generate_maintenance_report() {
    local report_file="$PROJECT_ROOT/logs/system-maintenance-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating maintenance report: $report_file"
    
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "PiMonitor System Maintenance Report"
        echo "=================================="
        echo "Date: $(date)"
        echo "Version: $MAINTENANCE_VERSION"
        echo ""
        
        echo "System Information:"
        echo "  OS: $SYSTEM_OS"
        echo "  Memory: $SYSTEM_MEMORY"
        echo "  Disk Usage: $SYSTEM_DISK_USAGE"
        echo "  Load Average: $SYSTEM_LOAD"
        echo ""
        
        echo "Maintenance Tasks Performed:"
        if [[ "$UPDATE_ONLY" != "true" ]] && [[ "$CLEAN_ONLY" != "true" ]]; then
            echo "  - System updates"
            echo "  - System cleanup"
        elif [[ "$UPDATE_ONLY" == "true" ]]; then
            echo "  - System updates only"
        elif [[ "$CLEAN_ONLY" == "true" ]]; then
            echo "  - System cleanup only"
        fi
        echo "  - Docker maintenance (if applicable)"
        echo ""
        
        echo "Reboot Status:"
        if [[ "$REBOOT_REQUIRED" == "true" ]]; then
            echo "  - Reboot required"
        else
            echo "  - No reboot required"
        fi
        
        if [[ "$AUTO_REBOOT" == "true" ]] && [[ "$REBOOT_REQUIRED" == "true" ]]; then
            echo "  - Auto-reboot scheduled"
        fi
        
    } > "$report_file"
    
    log_info "Maintenance report saved to: $report_file"
}

# Handle system reboot
handle_reboot() {
    check_reboot_required
    
    if [[ "$REBOOT_REQUIRED" == "true" ]]; then
        if [[ "$AUTO_REBOOT" == "true" ]]; then
            log_warn "System reboot required and auto-reboot enabled"
            log_warn "System will reboot in 60 seconds..."
            sleep 60
            sudo reboot
        else
            log_warn "System reboot is required"
            if [[ "$FORCE" != "true" ]]; then
                if confirm "Reboot system now?" "n"; then
                    sudo reboot
                else
                    log_info "Reboot postponed. Please reboot manually when convenient."
                fi
            else
                log_info "Reboot required but not forced. Please reboot manually when convenient."
            fi
        fi
    else
        log_info "No system reboot required"
    fi
}

# Main maintenance function
perform_maintenance() {
    # Check system requirements
    check_system_requirements
    
    # Get system information
    get_system_info
    
    # Confirm maintenance if not forced
    if [[ "$FORCE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        log_warn "This will perform system maintenance tasks"
        if ! confirm "Are you sure you want to continue?" "y"; then
            log_info "Maintenance cancelled by user"
            return 0
        fi
    fi
    
    # Perform maintenance tasks based on options
    if [[ "$CLEAN_ONLY" != "true" ]]; then
        perform_system_updates
    fi
    
    if [[ "$UPDATE_ONLY" != "true" ]]; then
        perform_system_cleanup
        perform_docker_maintenance
    fi
    
    # Generate report
    generate_maintenance_report
    
    # Handle reboot if needed
    if [[ "$DRY_RUN" != "true" ]]; then
        handle_reboot
    fi
    
    log_info "System maintenance completed successfully!"
}

# Cleanup function for script exit
cleanup() {
    log_info "System maintenance script finished"
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
    
    # Perform maintenance
    perform_maintenance
}

# Run main function
main "$@"