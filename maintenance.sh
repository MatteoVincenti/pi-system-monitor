#!/bin/bash

# PiMonitor Maintenance Script
# Consolidated system maintenance, cleanup, and validation operations

set -e

# Determine script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Override SCRIPT_DIR for library sourcing to avoid path conflicts
LIB_SCRIPT_DIR="$SCRIPT_DIR"

# Source shared libraries
# shellcheck source=./scripts/lib/common.sh
source "$LIB_SCRIPT_DIR/scripts/lib/common.sh"
# shellcheck source=./scripts/lib/branding.sh
source "$LIB_SCRIPT_DIR/scripts/lib/branding.sh"
# shellcheck source=./scripts/lib/docker.sh
source "$LIB_SCRIPT_DIR/scripts/lib/docker.sh"

# Configuration
readonly MAINTENANCE_VERSION="2.0.0"

# Initialize branding system
init_branding

# =============================================================================
# Menu Functions
# =============================================================================

# Main maintenance menu
main_menu() {
    while true; do
        clear
        show_pimonitor_logo
        
        echo -e "${WHITE}${BOLD}Maintenance & System Operations${NC}"
        show_separator
        
        local options=(
            "System Maintenance"
            "System Cleanup"
            "Compatibility Check"
            "Docker Cleanup"
            "System Validation"
            "Performance Check"
            "Generate Reports"
            "Exit"
        )
        
        echo "Please select a maintenance operation:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1) system_maintenance_menu; break ;;
                2) system_cleanup_menu; break ;;
                3) compatibility_check; break ;;
                4) docker_cleanup_menu; break ;;
                5) system_validation; break ;;
                6) performance_check; break ;;
                7) reports_menu; break ;;
                8) 
                    echo
                    show_info "Maintenance operations completed"
                    exit 0
                    ;;
                *)
                    show_error "Invalid selection. Please choose 1-8."
                    echo
                    ;;
            esac
        done
    done
}

# System maintenance submenu
system_maintenance_menu() {
    while true; do
        clear
        show_compact_header "System Maintenance"
        
        local options=(
            "Full System Maintenance"
            "Update Packages Only"
            "System Cleanup Only"
            "Scheduled Maintenance"
            "Back to Main Menu"
        )
        
        echo "Select maintenance type:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    show_progress "Running full system maintenance"
                    if perform_full_maintenance; then
                        show_success "Full system maintenance completed"
                    else
                        show_error "System maintenance encountered issues"
                    fi
                    pause_for_user
                    break
                    ;;
                2)
                    show_progress "Updating packages"
                    if perform_system_updates; then
                        show_success "Package updates completed"
                    else
                        show_error "Package updates failed"
                    fi
                    pause_for_user
                    break
                    ;;
                3)
                    show_progress "Running system cleanup"
                    if perform_system_cleanup; then
                        show_success "System cleanup completed"
                    else
                        show_error "System cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                4)
                    scheduled_maintenance_menu
                    break
                    ;;
                5) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-5."
                    echo
                    ;;
            esac
        done
    done
}

# System cleanup submenu
system_cleanup_menu() {
    while true; do
        clear
        show_compact_header "System Cleanup"
        
        local options=(
            "Complete Cleanup"
            "Clean Log Files"
            "Clean Temporary Files"
            "Clean Package Cache"
            "Remove Old Files"
            "Back to Main Menu"
        )
        
        echo "Select cleanup type:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    show_progress "Running complete cleanup"
                    if run_complete_cleanup; then
                        show_success "Complete cleanup finished"
                    else
                        show_error "Cleanup encountered issues"
                    fi
                    pause_for_user
                    break
                    ;;
                2)
                    show_progress "Cleaning log files"
                    if clean_log_files; then
                        show_success "Log files cleaned"
                    else
                        show_error "Log cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                3)
                    show_progress "Cleaning temporary files"
                    if clean_temporary_files; then
                        show_success "Temporary files cleaned"
                    else
                        show_error "Temporary file cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                4)
                    show_progress "Cleaning package cache"
                    if clean_package_caches; then
                        show_success "Package cache cleaned"
                    else
                        show_error "Package cache cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                5)
                    show_progress "Removing old files"
                    if clean_old_files; then
                        show_success "Old files removed"
                    else
                        show_error "Old file cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                6) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-6."
                    echo
                    ;;
            esac
        done
    done
}

# Docker cleanup submenu
docker_cleanup_menu() {
    while true; do
        clear
        show_compact_header "Docker Cleanup"
        
        echo "Current Docker usage:"
        if command_exists docker; then
            docker system df 2>/dev/null || echo "Docker not available"
        else
            echo "Docker not installed"
        fi
        echo
        
        local options=(
            "Safe Docker Cleanup"
            "Aggressive Docker Cleanup"
            "Clean Containers Only"
            "Clean Images Only"
            "Clean Volumes (DANGEROUS)"
            "Back to Main Menu"
        )
        
        echo "Select Docker cleanup type:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    show_progress "Running safe Docker cleanup"
                    if docker_safe_cleanup; then
                        show_success "Safe Docker cleanup completed"
                    else
                        show_error "Docker cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                2)
                    show_warning "This will remove ALL unused Docker resources"
                    read -p "Are you sure? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        show_progress "Running aggressive Docker cleanup"
                        if docker_aggressive_cleanup; then
                            show_success "Aggressive Docker cleanup completed"
                        else
                            show_error "Docker cleanup failed"
                        fi
                    else
                        show_info "Cleanup cancelled"
                    fi
                    pause_for_user
                    break
                    ;;
                3)
                    show_progress "Cleaning Docker containers"
                    if docker_clean_containers; then
                        show_success "Docker containers cleaned"
                    else
                        show_error "Container cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                4)
                    show_progress "Cleaning Docker images"
                    if docker_clean_images; then
                        show_success "Docker images cleaned"
                    else
                        show_error "Image cleanup failed"
                    fi
                    pause_for_user
                    break
                    ;;
                5)
                    show_warning "This will remove ALL unused Docker volumes and may delete data!"
                    read -p "Type 'DELETE' to confirm: " confirm
                    if [[ "$confirm" == "DELETE" ]]; then
                        show_progress "Cleaning Docker volumes"
                        if docker_clean_volumes; then
                            show_success "Docker volumes cleaned"
                        else
                            show_error "Volume cleanup failed"
                        fi
                    else
                        show_info "Volume cleanup cancelled"
                    fi
                    pause_for_user
                    break
                    ;;
                6) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-6."
                    echo
                    ;;
            esac
        done
    done
}

# Scheduled maintenance submenu
scheduled_maintenance_menu() {
    while true; do
        clear
        show_compact_header "Scheduled Maintenance"
        
        local options=(
            "Setup Daily Maintenance"
            "Setup Weekly Maintenance"
            "Setup Monthly Maintenance"
            "View Current Schedule"
            "Remove Scheduled Tasks"
            "Back to Maintenance Menu"
        )
        
        echo "Select scheduling option:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    setup_daily_maintenance
                    pause_for_user
                    break
                    ;;
                2)
                    setup_weekly_maintenance
                    pause_for_user
                    break
                    ;;
                3)
                    setup_monthly_maintenance
                    pause_for_user
                    break
                    ;;
                4)
                    view_maintenance_schedule
                    pause_for_user
                    break
                    ;;
                5)
                    remove_scheduled_maintenance
                    pause_for_user
                    break
                    ;;
                6) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-6."
                    echo
                    ;;
            esac
        done
    done
}

# Reports menu
reports_menu() {
    while true; do
        clear
        show_compact_header "System Reports"
        
        local options=(
            "Generate System Report"
            "Generate Maintenance Report"
            "Generate Compatibility Report"
            "Generate Performance Report"
            "View Recent Reports"
            "Back to Main Menu"
        )
        
        echo "Select report type:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    show_progress "Generating system report"
                    if generate_system_report; then
                        show_success "System report generated"
                    else
                        show_error "Report generation failed"
                    fi
                    pause_for_user
                    break
                    ;;
                2)
                    show_progress "Generating maintenance report"
                    if generate_maintenance_report; then
                        show_success "Maintenance report generated"
                    else
                        show_error "Report generation failed"
                    fi
                    pause_for_user
                    break
                    ;;
                3)
                    show_progress "Generating compatibility report"
                    if generate_compatibility_report; then
                        show_success "Compatibility report generated"
                    else
                        show_error "Report generation failed"
                    fi
                    pause_for_user
                    break
                    ;;
                4)
                    show_progress "Generating performance report"
                    if generate_performance_report; then
                        show_success "Performance report generated"
                    else
                        show_error "Report generation failed"
                    fi
                    pause_for_user
                    break
                    ;;
                5)
                    view_recent_reports
                    pause_for_user
                    break
                    ;;
                6) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-6."
                    echo
                    ;;
            esac
        done
    done
}

# =============================================================================
# Maintenance Functions
# =============================================================================

# Perform full system maintenance
perform_full_maintenance() {
    log_info "Starting full system maintenance..."
    
    # Update packages
    if ! perform_system_updates; then
        log_error "Package updates failed"
        return 1
    fi
    
    # System cleanup
    if ! perform_system_cleanup; then
        log_error "System cleanup failed"
        return 1
    fi
    
    # Docker maintenance
    if command_exists docker; then
        if ! docker_safe_cleanup; then
            log_warn "Docker cleanup encountered issues"
        fi
    fi
    
    # Check if reboot is required
    check_reboot_required
    
    log_info "Full system maintenance completed"
    return 0
}

# Perform system updates
perform_system_updates() {
    log_info "Performing system updates..."
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "Sudo access required for system updates"
        return 1
    fi
    
    # Update package lists
    log_info "Updating package lists..."
    if ! sudo apt update -y; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Check for upgrades
    local upgradable
    upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    
    if [[ $upgradable -gt 0 ]]; then
        log_info "Found $upgradable packages to upgrade"
        
        # Upgrade packages
        if ! sudo apt full-upgrade -y; then
            log_error "Package upgrade failed"
            return 1
        fi
        
        # Distribution upgrade
        if ! sudo apt dist-upgrade -y; then
            log_warn "Distribution upgrade encountered issues"
        fi
        
        # Fix broken dependencies
        if ! sudo apt --fix-broken --fix-missing install -y; then
            log_warn "Dependency fixes encountered issues"
        fi
    else
        log_info "System is already up to date"
    fi
    
    return 0
}

# Perform system cleanup
perform_system_cleanup() {
    log_info "Performing system cleanup..."
    
    # Remove unnecessary packages
    if sudo apt autoremove --purge -y; then
        log_info "Unnecessary packages removed"
    else
        log_warn "Package removal encountered issues"
    fi
    
    # Clean package cache
    if sudo apt autoclean -y && sudo apt clean -y; then
        log_info "Package cache cleaned"
    else
        log_warn "Package cache cleanup encountered issues"
    fi
    
    # Clean temporary files
    clean_temporary_files
    
    # Clean log files
    clean_log_files
    
    return 0
}

# Run complete cleanup
run_complete_cleanup() {
    log_info "Running complete system cleanup..."
    
    clean_log_files
    clean_temporary_files
    clean_package_caches
    clean_old_files
    
    if command_exists docker; then
        docker_safe_cleanup
    fi
    
    return 0
}

# Clean log files
clean_log_files() {
    log_info "Cleaning log files..."
    
    local log_dirs=(
        "$PROJECT_ROOT/logs"
        "/var/log"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            # Remove old log files (older than 30 days)
            find "$log_dir" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
            
            # Truncate large log files (larger than 100MB)
            find "$log_dir" -name "*.log" -type f -size +100M -exec truncate -s 0 {} \; 2>/dev/null || true
        fi
    done
    
    # Clean journald logs
    if command_exists journalctl; then
        sudo journalctl --vacuum-time=7d 2>/dev/null || true
    fi
    
    return 0
}

# Clean temporary files
clean_temporary_files() {
    log_info "Cleaning temporary files..."
    
    local temp_dirs=("/tmp" "/var/tmp" "$HOME/.cache")
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            # Clean files older than 7 days
            find "$temp_dir" -type f -atime +7 -delete 2>/dev/null || true
        fi
    done
    
    return 0
}

# Clean package caches
clean_package_caches() {
    log_info "Cleaning package caches..."
    
    # APT cache
    if command_exists apt-get; then
        sudo apt-get clean >/dev/null 2>&1 || true
        sudo apt-get autoremove -y >/dev/null 2>&1 || true
    fi
    
    # Snap cache
    if command_exists snap; then
        sudo snap set system refresh.retain=2 >/dev/null 2>&1 || true
    fi
    
    return 0
}

# Clean old files
clean_old_files() {
    log_info "Removing old and legacy files..."
    
    local old_patterns=(
        "*.tmp"
        "*.bak"
        "*.old"
        "docker-compose.homarr.yaml"
        "docker-compose.portainer.yaml"
    )
    
    for pattern in "${old_patterns[@]}"; do
        find "$PROJECT_ROOT" -name "$pattern" -type f -delete 2>/dev/null || true
    done
    
    # Remove old directories
    local old_dirs=(
        "$PROJECT_ROOT/configs/homarr"
        "$PROJECT_ROOT/data/homarr"
    )
    
    for dir in "${old_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir" 2>/dev/null || true
        fi
    done
    
    return 0
}

# Docker cleanup functions
docker_safe_cleanup() {
    log_info "Running safe Docker cleanup..."
    
    if ! command_exists docker; then
        log_warn "Docker not installed"
        return 1
    fi
    
    # Clean stopped containers
    docker container prune -f >/dev/null 2>&1 || true
    
    # Clean unused images
    docker image prune -f >/dev/null 2>&1 || true
    
    # Clean unused networks
    docker network prune -f >/dev/null 2>&1 || true
    
    # Clean build cache
    docker builder prune -f >/dev/null 2>&1 || true
    
    return 0
}

docker_aggressive_cleanup() {
    log_info "Running aggressive Docker cleanup..."
    
    if ! command_exists docker; then
        log_warn "Docker not installed"
        return 1
    fi
    
    # Stop all containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # Remove all containers
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove all images
    docker rmi $(docker images -q) 2>/dev/null || true
    
    # System prune
    docker system prune -af >/dev/null 2>&1 || true
    
    return 0
}

docker_clean_containers() {
    log_info "Cleaning Docker containers..."
    docker container prune -f >/dev/null 2>&1 || true
    return 0
}

docker_clean_images() {
    log_info "Cleaning Docker images..."
    docker image prune -af >/dev/null 2>&1 || true
    return 0
}

docker_clean_volumes() {
    log_info "Cleaning Docker volumes..."
    docker volume prune -f >/dev/null 2>&1 || true
    return 0
}

# Compatibility check
compatibility_check() {
    clear
    show_compact_header "Raspberry Pi Compatibility Check"
    
    show_progress "Running compatibility check"
    
    if "$SCRIPT_DIR/scripts/pi-compatibility-check.sh"; then
        show_success "Compatibility check completed"
    else
        show_error "Compatibility check failed"
    fi
    
    pause_for_user
}

# System validation
system_validation() {
    clear
    show_compact_header "System Validation"
    
    show_progress "Running system validation"
    
    if "$SCRIPT_DIR/scripts/system-validation.sh"; then
        show_success "System validation completed"
    else
        show_error "System validation failed"
    fi
    
    pause_for_user
}

# Performance check
performance_check() {
    clear
    show_compact_header "Performance Check"
    
    show_progress "Checking system performance"
    
    echo "System Performance Report:"
    echo "========================="
    echo "CPU Cores: $(nproc)"
    echo "Memory: $(free -h | awk 'NR==2{print $2}')"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
    echo "Uptime: $(uptime -p)"
    
    if command_exists docker; then
        echo ""
        echo "Docker Resources:"
        docker system df 2>/dev/null || echo "Docker not available"
    fi
    
    show_success "Performance check completed"
    pause_for_user
}

# Check if reboot is required
check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        show_warning "System reboot is required"
        read -p "Reboot now? (y/N): " reboot_now
        if [[ "$reboot_now" =~ ^[Yy]$ ]]; then
            show_info "Rebooting system..."
            sudo reboot
        fi
    fi
}

# Scheduling functions
setup_daily_maintenance() {
    show_info "Setting up daily maintenance at 2:00 AM"
    
    local cron_job="0 2 * * * $SCRIPT_DIR/maintenance.sh --auto-maintenance"
    
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    show_success "Daily maintenance scheduled"
}

setup_weekly_maintenance() {
    show_info "Setting up weekly maintenance on Sunday at 3:00 AM"
    
    local cron_job="0 3 * * 0 $SCRIPT_DIR/maintenance.sh --auto-maintenance --full"
    
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    show_success "Weekly maintenance scheduled"
}

setup_monthly_maintenance() {
    show_info "Setting up monthly maintenance on 1st at 4:00 AM"
    
    local cron_job="0 4 1 * * $SCRIPT_DIR/maintenance.sh --auto-maintenance --full --cleanup"
    
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    show_success "Monthly maintenance scheduled"
}

view_maintenance_schedule() {
    show_info "Current maintenance schedule:"
    echo
    crontab -l 2>/dev/null | grep "maintenance.sh" || echo "No scheduled maintenance found"
}

remove_scheduled_maintenance() {
    show_info "Removing scheduled maintenance tasks"
    
    crontab -l 2>/dev/null | grep -v "maintenance.sh" | crontab -
    
    show_success "Scheduled maintenance removed"
}

# Report generation functions
generate_system_report() {
    local report_file="$PROJECT_ROOT/logs/system-report-$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$PROJECT_ROOT/logs"
    
    {
        echo "PiMonitor System Report"
        echo "======================"
        echo "Generated: $(date)"
        echo ""
        
        echo "System Information:"
        echo "Hostname: $(hostname)"
        echo "OS: $(get_os_info)"
        echo "Architecture: $(uname -m)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime -p)"
        echo ""
        
        echo "Hardware:"
        echo "CPU Cores: $(nproc)"
        echo "Memory: $(free -h | awk 'NR==2{print $2}')"
        echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        
        echo "Storage:"
        df -h
        echo ""
        
        if command_exists docker; then
            echo "Docker:"
            docker system df
        fi
        
    } > "$report_file"
    
    log_info "System report saved to: $report_file"
    return 0
}

generate_maintenance_report() {
    local report_file="$PROJECT_ROOT/logs/maintenance-report-$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$PROJECT_ROOT/logs"
    
    {
        echo "PiMonitor Maintenance Report"
        echo "==========================="
        echo "Generated: $(date)"
        echo ""
        
        echo "Last Maintenance Activities:"
        echo "Package Updates: $(stat -c %y /var/lib/apt/lists 2>/dev/null | cut -d' ' -f1 || echo 'Unknown')"
        echo "System Cleanup: $(find /tmp -name '.cleanup-*' -printf '%TY-%Tm-%Td\n' 2>/dev/null | tail -1 || echo 'Unknown')"
        echo ""
        
        echo "System Health:"
        echo "Reboot Required: $(test -f /var/run/reboot-required && echo 'Yes' || echo 'No')"
        echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
        echo "Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
        
    } > "$report_file"
    
    log_info "Maintenance report saved to: $report_file"
    return 0
}

generate_compatibility_report() {
    "$SCRIPT_DIR/scripts/pi-compatibility-check.sh" --report
    return 0
}

generate_performance_report() {
    local report_file="$PROJECT_ROOT/logs/performance-report-$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$PROJECT_ROOT/logs"
    
    {
        echo "PiMonitor Performance Report"
        echo "==========================="
        echo "Generated: $(date)"
        echo ""
        
        echo "CPU Performance:"
        echo "Cores: $(nproc)"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        
        echo "Memory Performance:"
        free -h
        echo ""
        
        echo "Disk Performance:"
        df -h
        echo ""
        
        echo "Network Performance:"
        echo "Interfaces: $(ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' ' | tr '\n' ' ')"
        
    } > "$report_file"
    
    log_info "Performance report saved to: $report_file"
    return 0
}

view_recent_reports() {
    show_info "Recent reports:"
    echo
    
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        ls -lt "$PROJECT_ROOT/logs"/*report*.txt 2>/dev/null | head -10 || echo "No reports found"
    else
        echo "No reports directory found"
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Pause for user input
pause_for_user() {
    echo
    read -p "Press Enter to continue..." -r
}

# Handle script interruption
cleanup() {
    echo
    show_info "Maintenance operations interrupted"
    exit 0
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Handle command line arguments
    case "${1:-}" in
        --auto-maintenance)
            # Automated maintenance mode
            log_info "Running automated maintenance"
            perform_full_maintenance
            exit $?
            ;;
        --help|-h)
            show_pimonitor_logo
            echo "PiMonitor Maintenance Script"
            echo
            echo "Usage:"
            echo "  $0                    # Interactive menu mode"
            echo "  $0 --auto-maintenance # Automated maintenance"
            echo "  $0 --help            # Show this help"
            echo
            exit 0
            ;;
        "")
            # Interactive mode
            main_menu
            ;;
        *)
            show_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"