#!/bin/bash

# PiMonitor Utilities Script
# Consolidated backup, logging, configuration, and utility operations

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
readonly UTILITIES_VERSION="2.0.0"

# Initialize branding system
init_branding

# =============================================================================
# Menu Functions
# =============================================================================

# Main utilities menu
main_menu() {
    while true; do
        clear
        show_pimonitor_logo
        
        echo -e "${WHITE}${BOLD}Utilities & Tools${NC}"
        show_separator
        
        local options=(
            "Backup Management"
            "Log Management"
            "Configuration Tools"
            "Secret Generation"
            "System Information"
            "Network Tools"
            "File Operations"
            "Exit"
        )
        
        echo "Please select a utility:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1) backup_menu; break ;;
                2) logs_menu; break ;;
                3) config_menu; break ;;
                4) secrets_menu; break ;;
                5) system_info_menu; break ;;
                6) network_menu; break ;;
                7) file_operations_menu; break ;;
                8) 
                    echo
                    show_info "Utilities session completed"
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

# Backup management menu
backup_menu() {
    while true; do
        clear
        show_compact_header "Backup Management"
        
        local options=(
            "Create Backup"
            "List Backups"
            "Restore Backup"
            "Delete Backup"
            "Verify Backup"
            "Export Backup"
            "Import Backup"
            "Cleanup Old Backups"
            "Back to Main Menu"
        )
        
        echo "Select backup operation:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    create_backup_interactive
                    pause_for_user
                    break
                    ;;
                2)
                    list_backups
                    pause_for_user
                    break
                    ;;
                3)
                    restore_backup_interactive
                    pause_for_user
                    break
                    ;;
                4)
                    delete_backup_interactive
                    pause_for_user
                    break
                    ;;
                5)
                    verify_backup_interactive
                    pause_for_user
                    break
                    ;;
                6)
                    export_backup_interactive
                    pause_for_user
                    break
                    ;;
                7)
                    import_backup_interactive
                    pause_for_user
                    break
                    ;;
                8)
                    cleanup_old_backups
                    pause_for_user
                    break
                    ;;
                9) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-9."
                    echo
                    ;;
            esac
        done
    done
}

# Log management menu
logs_menu() {
    while true; do
        clear
        show_compact_header "Log Management"
        
        local options=(
            "View All Service Logs"
            "View Specific Service Logs"
            "Follow Live Logs"
            "Search Logs"
            "Export Logs"
            "Clear Service Logs"
            "Log Statistics"
            "Back to Main Menu"
        )
        
        echo "Select log operation:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    show_all_service_logs
                    pause_for_user
                    break
                    ;;
                2)
                    view_specific_service_logs
                    pause_for_user
                    break
                    ;;
                3)
                    follow_live_logs
                    pause_for_user
                    break
                    ;;
                4)
                    search_logs_interactive
                    pause_for_user
                    break
                    ;;
                5)
                    export_logs_interactive
                    pause_for_user
                    break
                    ;;
                6)
                    clear_service_logs_interactive
                    pause_for_user
                    break
                    ;;
                7)
                    show_log_statistics
                    pause_for_user
                    break
                    ;;
                8) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-8."
                    echo
                    ;;
            esac
        done
    done
}

# Configuration tools menu
config_menu() {
    while true; do
        clear
        show_compact_header "Configuration Tools"
        
        local options=(
            "Validate Configuration"
            "Generate Configuration"
            "Compare Environments"
            "Configuration Health Check"
            "Edit Configuration Files"
            "Reset Configuration"
            "Back to Main Menu"
        )
        
        echo "Select configuration operation:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    validate_configuration_interactive
                    pause_for_user
                    break
                    ;;
                2)
                    generate_configuration_interactive
                    pause_for_user
                    break
                    ;;
                3)
                    compare_environments_interactive
                    pause_for_user
                    break
                    ;;
                4)
                    configuration_health_check
                    pause_for_user
                    break
                    ;;
                5)
                    edit_configuration_files
                    pause_for_user
                    break
                    ;;
                6)
                    reset_configuration_interactive
                    pause_for_user
                    break
                    ;;
                7) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-7."
                    echo
                    ;;
            esac
        done
    done
}

# Secrets management menu
secrets_menu() {
    while true; do
        clear
        show_compact_header "Secret Generation & Management"
        
        local options=(
            "Generate All Secrets"
            "Generate Grafana Password"
            "Generate InfluxDB Token"
            "Generate Prometheus Password"
            "Generate Random Password"
            "Generate API Key"
            "View Current Secrets"
            "Back to Main Menu"
        )
        
        echo "Select secret operation:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    generate_all_secrets
                    pause_for_user
                    break
                    ;;
                2)
                    generate_grafana_password
                    pause_for_user
                    break
                    ;;
                3)
                    generate_influxdb_token
                    pause_for_user
                    break
                    ;;
                4)
                    generate_prometheus_password
                    pause_for_user
                    break
                    ;;
                5)
                    generate_random_password_interactive
                    pause_for_user
                    break
                    ;;
                6)
                    generate_api_key
                    pause_for_user
                    break
                    ;;
                7)
                    view_current_secrets
                    pause_for_user
                    break
                    ;;
                8) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-8."
                    echo
                    ;;
            esac
        done
    done
}

# System information menu
system_info_menu() {
    while true; do
        clear
        show_compact_header "System Information"
        
        local options=(
            "System Overview"
            "Hardware Information"
            "Docker Information"
            "Network Information"
            "Storage Information"
            "Service Status"
            "Performance Metrics"
            "Back to Main Menu"
        )
        
        echo "Select information type:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    show_system_overview
                    pause_for_user
                    break
                    ;;
                2)
                    show_hardware_information
                    pause_for_user
                    break
                    ;;
                3)
                    show_docker_information
                    pause_for_user
                    break
                    ;;
                4)
                    show_network_information
                    pause_for_user
                    break
                    ;;
                5)
                    show_storage_information
                    pause_for_user
                    break
                    ;;
                6)
                    show_service_status
                    pause_for_user
                    break
                    ;;
                7)
                    show_performance_metrics
                    pause_for_user
                    break
                    ;;
                8) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-8."
                    echo
                    ;;
            esac
        done
    done
}

# Network tools menu
network_menu() {
    while true; do
        clear
        show_compact_header "Network Tools"
        
        local options=(
            "Port Scanner"
            "Connectivity Test"
            "DNS Lookup"
            "Network Speed Test"
            "Service URLs"
            "Firewall Status"
            "Back to Main Menu"
        )
        
        echo "Select network tool:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    port_scanner_interactive
                    pause_for_user
                    break
                    ;;
                2)
                    connectivity_test
                    pause_for_user
                    break
                    ;;
                3)
                    dns_lookup_interactive
                    pause_for_user
                    break
                    ;;
                4)
                    network_speed_test
                    pause_for_user
                    break
                    ;;
                5)
                    show_service_urls
                    pause_for_user
                    break
                    ;;
                6)
                    show_firewall_status
                    pause_for_user
                    break
                    ;;
                7) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-7."
                    echo
                    ;;
            esac
        done
    done
}

# File operations menu
file_operations_menu() {
    while true; do
        clear
        show_compact_header "File Operations"
        
        local options=(
            "Find Files"
            "Disk Usage Analysis"
            "File Permissions Check"
            "Cleanup Temporary Files"
            "Archive Old Files"
            "File Integrity Check"
            "Back to Main Menu"
        )
        
        echo "Select file operation:"
        echo
        
        select choice in "${options[@]}"; do
            case $REPLY in
                1)
                    find_files_interactive
                    pause_for_user
                    break
                    ;;
                2)
                    disk_usage_analysis
                    pause_for_user
                    break
                    ;;
                3)
                    file_permissions_check
                    pause_for_user
                    break
                    ;;
                4)
                    cleanup_temporary_files
                    pause_for_user
                    break
                    ;;
                5)
                    archive_old_files_interactive
                    pause_for_user
                    break
                    ;;
                6)
                    file_integrity_check
                    pause_for_user
                    break
                    ;;
                7) return ;;
                *)
                    show_error "Invalid selection. Please choose 1-7."
                    echo
                    ;;
            esac
        done
    done
}

# =============================================================================
# Backup Functions
# =============================================================================

create_backup_interactive() {
    echo "Create Backup"
    echo "============="
    
    read -p "Enter backup name (or press Enter for auto-generated): " backup_name
    
    show_progress "Creating backup"
    
    if [[ -n "$backup_name" ]]; then
        if "$SCRIPT_DIR/scripts/backup.sh" create "$backup_name"; then
            show_success "Backup created: $backup_name"
        else
            show_error "Backup creation failed"
        fi
    else
        if "$SCRIPT_DIR/scripts/backup.sh" create; then
            show_success "Backup created successfully"
        else
            show_error "Backup creation failed"
        fi
    fi
}

list_backups() {
    echo "Available Backups"
    echo "================="
    "$SCRIPT_DIR/scripts/backup.sh" list
}

restore_backup_interactive() {
    echo "Restore Backup"
    echo "=============="
    
    echo "Available backups:"
    "$SCRIPT_DIR/scripts/backup.sh" list
    echo
    
    read -p "Enter backup name to restore: " backup_name
    
    if [[ -n "$backup_name" ]]; then
        show_warning "This will overwrite current data!"
        read -p "Are you sure? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            show_progress "Restoring backup: $backup_name"
            if "$SCRIPT_DIR/scripts/backup.sh" restore "$backup_name"; then
                show_success "Backup restored successfully"
            else
                show_error "Backup restoration failed"
            fi
        else
            show_info "Restore cancelled"
        fi
    else
        show_error "Backup name required"
    fi
}

delete_backup_interactive() {
    echo "Delete Backup"
    echo "============="
    
    echo "Available backups:"
    "$SCRIPT_DIR/scripts/backup.sh" list
    echo
    
    read -p "Enter backup name to delete: " backup_name
    
    if [[ -n "$backup_name" ]]; then
        show_warning "This will permanently delete the backup!"
        read -p "Are you sure? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            show_progress "Deleting backup: $backup_name"
            if "$SCRIPT_DIR/scripts/backup.sh" delete "$backup_name" --force; then
                show_success "Backup deleted successfully"
            else
                show_error "Backup deletion failed"
            fi
        else
            show_info "Deletion cancelled"
        fi
    else
        show_error "Backup name required"
    fi
}

verify_backup_interactive() {
    echo "Verify Backup"
    echo "============="
    
    echo "Available backups:"
    "$SCRIPT_DIR/scripts/backup.sh" list
    echo
    
    read -p "Enter backup name to verify: " backup_name
    
    if [[ -n "$backup_name" ]]; then
        show_progress "Verifying backup: $backup_name"
        if "$SCRIPT_DIR/scripts/backup.sh" verify "$backup_name"; then
            show_success "Backup verification passed"
        else
            show_error "Backup verification failed"
        fi
    else
        show_error "Backup name required"
    fi
}

export_backup_interactive() {
    echo "Export Backup"
    echo "============="
    
    echo "Available backups:"
    "$SCRIPT_DIR/scripts/backup.sh" list
    echo
    
    read -p "Enter backup name to export: " backup_name
    
    if [[ -n "$backup_name" ]]; then
        show_progress "Exporting backup: $backup_name"
        if "$SCRIPT_DIR/scripts/backup.sh" export "$backup_name"; then
            show_success "Backup exported successfully"
        else
            show_error "Backup export failed"
        fi
    else
        show_error "Backup name required"
    fi
}

import_backup_interactive() {
    echo "Import Backup"
    echo "============="
    
    read -p "Enter path to backup file: " backup_file
    
    if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
        show_progress "Importing backup: $backup_file"
        if "$SCRIPT_DIR/scripts/backup.sh" import "$backup_file"; then
            show_success "Backup imported successfully"
        else
            show_error "Backup import failed"
        fi
    else
        show_error "Valid backup file path required"
    fi
}

cleanup_old_backups() {
    echo "Cleanup Old Backups"
    echo "==================="
    
    show_progress "Cleaning up old backups"
    if "$SCRIPT_DIR/scripts/backup.sh" cleanup; then
        show_success "Old backups cleaned up"
    else
        show_error "Backup cleanup failed"
    fi
}

# =============================================================================
# Log Functions
# =============================================================================

show_all_service_logs() {
    echo "All Service Logs"
    echo "================"
    
    show_info "Showing recent logs from all services (Press Ctrl+C to exit)"
    "$SCRIPT_DIR/scripts/logs.sh" all -n 50
}

view_specific_service_logs() {
    echo "Specific Service Logs"
    echo "===================="
    
    local services=("grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    echo "Available services:"
    for i in "${!services[@]}"; do
        echo "$((i+1)). ${services[i]}"
    done
    echo
    
    read -p "Select service (1-${#services[@]}): " service_choice
    
    if [[ "$service_choice" =~ ^[1-6]$ ]]; then
        local service="${services[$((service_choice-1))]}"
        show_info "Showing logs for $service (Press Ctrl+C to exit)"
        "$SCRIPT_DIR/scripts/logs.sh" "$service" -n 100
    else
        show_error "Invalid service selection"
    fi
}

follow_live_logs() {
    echo "Follow Live Logs"
    echo "================"
    
    local services=("all" "grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    echo "Available options:"
    for i in "${!services[@]}"; do
        echo "$((i+1)). ${services[i]}"
    done
    echo
    
    read -p "Select service (1-${#services[@]}): " service_choice
    
    if [[ "$service_choice" =~ ^[1-7]$ ]]; then
        local service="${services[$((service_choice-1))]}"
        show_info "Following live logs for $service (Press Ctrl+C to exit)"
        "$SCRIPT_DIR/scripts/logs.sh" "$service" --follow
    else
        show_error "Invalid service selection"
    fi
}

search_logs_interactive() {
    echo "Search Logs"
    echo "==========="
    
    read -p "Enter search pattern: " pattern
    
    if [[ -n "$pattern" ]]; then
        show_info "Searching for: $pattern"
        "$SCRIPT_DIR/scripts/logs.sh" all --grep "$pattern" -n 200
    else
        show_error "Search pattern required"
    fi
}

export_logs_interactive() {
    echo "Export Logs"
    echo "==========="
    
    read -p "Enter export filename (or press Enter for auto-generated): " filename
    
    show_progress "Exporting logs"
    
    if [[ -n "$filename" ]]; then
        if "$SCRIPT_DIR/scripts/logs.sh" export "$filename"; then
            show_success "Logs exported: $filename"
        else
            show_error "Log export failed"
        fi
    else
        if "$SCRIPT_DIR/scripts/logs.sh" export; then
            show_success "Logs exported successfully"
        else
            show_error "Log export failed"
        fi
    fi
}

clear_service_logs_interactive() {
    echo "Clear Service Logs"
    echo "=================="
    
    local services=("all" "grafana" "influxdb" "prometheus" "loki" "alloy" "telegraf")
    
    echo "Available options:"
    for i in "${!services[@]}"; do
        echo "$((i+1)). ${services[i]}"
    done
    echo
    
    read -p "Select service (1-${#services[@]}): " service_choice
    
    if [[ "$service_choice" =~ ^[1-7]$ ]]; then
        local service="${services[$((service_choice-1))]}"
        
        show_warning "This will clear all logs for $service"
        read -p "Are you sure? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            show_progress "Clearing logs for $service"
            if "$SCRIPT_DIR/scripts/logs.sh" "$service" --clear; then
                show_success "Logs cleared for $service"
            else
                show_error "Log clearing failed"
            fi
        else
            show_info "Operation cancelled"
        fi
    else
        show_error "Invalid service selection"
    fi
}

show_log_statistics() {
    echo "Log Statistics"
    echo "=============="
    
    "$SCRIPT_DIR/scripts/logs.sh" stats
}

# =============================================================================
# Configuration Functions
# =============================================================================

validate_configuration_interactive() {
    echo "Validate Configuration"
    echo "====================="
    
    local environments=("all" "development" "production" "staging")
    
    echo "Available environments:"
    for i in "${!environments[@]}"; do
        echo "$((i+1)). ${environments[i]}"
    done
    echo
    
    read -p "Select environment (1-${#environments[@]}): " env_choice
    
    if [[ "$env_choice" =~ ^[1-4]$ ]]; then
        local env="${environments[$((env_choice-1))]}"
        show_progress "Validating $env configuration"
        
        if "$SCRIPT_DIR/scripts/validate-config.sh" "$env"; then
            show_success "Configuration validation passed"
        else
            show_error "Configuration validation failed"
        fi
    else
        show_error "Invalid environment selection"
    fi
}

generate_configuration_interactive() {
    echo "Generate Configuration"
    echo "====================="
    
    local environments=("development" "production" "staging")
    
    echo "Available environments:"
    for i in "${!environments[@]}"; do
        echo "$((i+1)). ${environments[i]}"
    done
    echo
    
    read -p "Select environment (1-${#environments[@]}): " env_choice
    
    if [[ "$env_choice" =~ ^[1-3]$ ]]; then
        local env="${environments[$((env_choice-1))]}"
        show_progress "Generating $env configuration"
        
        if "$SCRIPT_DIR/scripts/config-manager.sh" generate "$env"; then
            show_success "Configuration generated for $env"
        else
            show_error "Configuration generation failed"
        fi
    else
        show_error "Invalid environment selection"
    fi
}

compare_environments_interactive() {
    echo "Compare Environments"
    echo "==================="
    
    local environments=("development" "production" "staging")
    
    echo "Available environments:"
    for i in "${!environments[@]}"; do
        echo "$((i+1)). ${environments[i]}"
    done
    echo
    
    read -p "Select first environment (1-${#environments[@]}): " env1_choice
    read -p "Select second environment (1-${#environments[@]}): " env2_choice
    
    if [[ "$env1_choice" =~ ^[1-3]$ ]] && [[ "$env2_choice" =~ ^[1-3]$ ]]; then
        local env1="${environments[$((env1_choice-1))]}"
        local env2="${environments[$((env2_choice-1))]}"
        
        show_info "Comparing $env1 vs $env2"
        "$SCRIPT_DIR/scripts/config-manager.sh" diff "$env1" "$env2"
    else
        show_error "Invalid environment selection"
    fi
}

configuration_health_check() {
    echo "Configuration Health Check"
    echo "========================="
    
    show_progress "Running configuration health check"
    
    if "$SCRIPT_DIR/scripts/config-manager.sh" check; then
        show_success "Configuration health check passed"
    else
        show_error "Configuration health check failed"
    fi
}

edit_configuration_files() {
    echo "Edit Configuration Files"
    echo "======================="
    
    local config_files=(
        ".env"
        "docker-compose.yml"
        "configs/grafana/grafana.ini"
        "configs/prometheus/prometheus.yml"
        "configs/loki/loki.yml"
    )
    
    echo "Available configuration files:"
    for i in "${!config_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/${config_files[i]}" ]]; then
            echo "$((i+1)). ${config_files[i]}"
        else
            echo "$((i+1)). ${config_files[i]} (not found)"
        fi
    done
    echo
    
    read -p "Select file to edit (1-${#config_files[@]}): " file_choice
    
    if [[ "$file_choice" =~ ^[1-5]$ ]]; then
        local config_file="${config_files[$((file_choice-1))]}"
        local full_path="$PROJECT_ROOT/$config_file"
        
        if [[ -f "$full_path" ]]; then
            show_info "Opening $config_file for editing"
            "${EDITOR:-nano}" "$full_path"
        else
            show_error "Configuration file not found: $config_file"
        fi
    else
        show_error "Invalid file selection"
    fi
}

reset_configuration_interactive() {
    echo "Reset Configuration"
    echo "=================="
    
    show_warning "This will reset configuration to defaults"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        show_progress "Resetting configuration"
        
        # Copy .env.example to .env
        if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            show_success "Environment configuration reset"
        else
            show_error ".env.example not found"
        fi
    else
        show_info "Reset cancelled"
    fi
}

# =============================================================================
# Secret Generation Functions
# =============================================================================

generate_all_secrets() {
    echo "Generate All Secrets"
    echo "==================="
    
    show_progress "Generating all secrets"
    
    if "$SCRIPT_DIR/scripts/generate-secrets.sh"; then
        show_success "All secrets generated successfully"
    else
        show_error "Secret generation failed"
    fi
}

generate_grafana_password() {
    echo "Generate Grafana Password"
    echo "========================"
    
    local password
    password=$(openssl rand -base64 32)
    
    echo "Generated Grafana password: $password"
    
    read -p "Save to secrets directory? (y/N): " save_secret
    
    if [[ "$save_secret" =~ ^[Yy]$ ]]; then
        mkdir -p "$PROJECT_ROOT/secrets"
        echo "$password" > "$PROJECT_ROOT/secrets/grafana_admin_password.txt"
        chmod 600 "$PROJECT_ROOT/secrets/grafana_admin_password.txt"
        show_success "Password saved to secrets/grafana_admin_password.txt"
    fi
}

generate_influxdb_token() {
    echo "Generate InfluxDB Token"
    echo "======================"
    
    local token
    token=$(openssl rand -hex 32)
    
    echo "Generated InfluxDB token: $token"
    
    read -p "Save to secrets directory? (y/N): " save_secret
    
    if [[ "$save_secret" =~ ^[Yy]$ ]]; then
        mkdir -p "$PROJECT_ROOT/secrets"
        echo "$token" > "$PROJECT_ROOT/secrets/influxdb_admin_token.txt"
        chmod 600 "$PROJECT_ROOT/secrets/influxdb_admin_token.txt"
        show_success "Token saved to secrets/influxdb_admin_token.txt"
    fi
}

generate_prometheus_password() {
    echo "Generate Prometheus Password"
    echo "==========================="
    
    local password
    password=$(openssl rand -base64 16)
    
    echo "Generated Prometheus password: $password"
    
    read -p "Save to secrets directory? (y/N): " save_secret
    
    if [[ "$save_secret" =~ ^[Yy]$ ]]; then
        mkdir -p "$PROJECT_ROOT/secrets"
        echo "$password" > "$PROJECT_ROOT/secrets/prometheus_admin_password.txt"
        chmod 600 "$PROJECT_ROOT/secrets/prometheus_admin_password.txt"
        show_success "Password saved to secrets/prometheus_admin_password.txt"
    fi
}

generate_random_password_interactive() {
    echo "Generate Random Password"
    echo "======================="
    
    read -p "Enter password length (default: 32): " length
    length=${length:-32}
    
    if [[ "$length" =~ ^[0-9]+$ ]] && [[ $length -ge 8 ]]; then
        local password
        password=$(openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length")
        
        echo "Generated password: $password"
        echo "Password strength: $(check_password_strength "$password")"
    else
        show_error "Invalid length (minimum 8 characters)"
    fi
}

generate_api_key() {
    echo "Generate API Key"
    echo "==============="
    
    local api_key
    api_key=$(openssl rand -hex 32)
    
    echo "Generated API key: $api_key"
    
    read -p "Save to secrets directory? (y/N): " save_secret
    
    if [[ "$save_secret" =~ ^[Yy]$ ]]; then
        mkdir -p "$PROJECT_ROOT/secrets"
        echo "$api_key" > "$PROJECT_ROOT/secrets/api_key.txt"
        chmod 600 "$PROJECT_ROOT/secrets/api_key.txt"
        show_success "API key saved to secrets/api_key.txt"
    fi
}

view_current_secrets() {
    echo "Current Secrets"
    echo "==============="
    
    if [[ -d "$PROJECT_ROOT/secrets" ]]; then
        echo "Available secret files:"
        ls -la "$PROJECT_ROOT/secrets/"
        echo
        
        read -p "View content of a secret file? (y/N): " view_content
        
        if [[ "$view_content" =~ ^[Yy]$ ]]; then
            read -p "Enter filename: " filename
            
            if [[ -f "$PROJECT_ROOT/secrets/$filename" ]]; then
                echo "Content of $filename:"
                cat "$PROJECT_ROOT/secrets/$filename"
            else
                show_error "Secret file not found: $filename"
            fi
        fi
    else
        show_warning "No secrets directory found"
    fi
}

check_password_strength() {
    local password="$1"
    local strength="Weak"
    
    if [[ ${#password} -ge 12 ]]; then
        if [[ "$password" =~ [A-Z] ]] && [[ "$password" =~ [a-z] ]] && [[ "$password" =~ [0-9] ]]; then
            if [[ "$password" =~ [^A-Za-z0-9] ]]; then
                strength="Very Strong"
            else
                strength="Strong"
            fi
        else
            strength="Medium"
        fi
    fi
    
    echo "$strength"
}

# =============================================================================
# System Information Functions
# =============================================================================

show_system_overview() {
    echo "System Overview"
    echo "==============="
    
    echo "Hostname: $(hostname)"
    echo "OS: $(get_os_info)"
    echo "Architecture: $(uname -m)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory: $(free -h | awk 'NR==2{print $3"/"$2}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
}

show_hardware_information() {
    echo "Hardware Information"
    echo "==================="
    
    echo "CPU:"
    echo "  Cores: $(nproc)"
    if [[ -f /proc/cpuinfo ]]; then
        echo "  Model: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    fi
    
    echo ""
    echo "Memory:"
    free -h
    
    echo ""
    echo "Storage:"
    df -h
    
    if [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo; then
        echo ""
        echo "Raspberry Pi Information:"
        grep -E "(Model|Revision|Serial)" /proc/cpuinfo
    fi
}

show_docker_information() {
    echo "Docker Information"
    echo "=================="
    
    if command_exists docker; then
        echo "Docker Version: $(docker --version)"
        echo "Docker Compose: $(docker compose version --short 2>/dev/null || echo 'Not available')"
        echo ""
        
        echo "Docker System Info:"
        docker system df
        echo ""
        
        echo "Running Containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "Docker not installed"
    fi
}

show_network_information() {
    echo "Network Information"
    echo "=================="
    
    echo "Network Interfaces:"
    ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^[[:space:]]*/  /'
    
    echo ""
    echo "Routing Table:"
    ip route show
    
    echo ""
    echo "DNS Configuration:"
    if [[ -f /etc/resolv.conf ]]; then
        grep nameserver /etc/resolv.conf
    fi
}

show_storage_information() {
    echo "Storage Information"
    echo "=================="
    
    echo "Disk Usage:"
    df -h
    
    echo ""
    echo "Disk I/O Statistics:"
    if command_exists iostat; then
        iostat -x 1 1
    else
        echo "iostat not available"
    fi
    
    echo ""
    echo "Mount Points:"
    mount | grep -E "^/dev" | column -t
}

show_service_status() {
    echo "Service Status"
    echo "=============="
    
    "$SCRIPT_DIR/scripts/deploy.sh" status
}

show_performance_metrics() {
    echo "Performance Metrics"
    echo "=================="
    
    echo "CPU Usage:"
    if command_exists top; then
        top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
    fi
    
    echo ""
    echo "Memory Usage:"
    free | awk 'NR==2{printf "%.1f%%\n", $3*100/$2}'
    
    echo ""
    echo "Load Average:"
    uptime | awk -F'load average:' '{print $2}'
    
    echo ""
    echo "Disk I/O:"
    if command_exists iotop; then
        iotop -b -n1 -a | head -10
    else
        echo "iotop not available"
    fi
}

# =============================================================================
# Network Functions
# =============================================================================

port_scanner_interactive() {
    echo "Port Scanner"
    echo "============"
    
    read -p "Enter host to scan (default: localhost): " host
    host=${host:-localhost}
    
    read -p "Enter port range (default: 1-1000): " port_range
    port_range=${port_range:-1-1000}
    
    show_progress "Scanning ports on $host"
    
    if command_exists nmap; then
        nmap -p "$port_range" "$host"
    else
        show_warning "nmap not available, using basic port check"
        
        IFS='-' read -r start_port end_port <<< "$port_range"
        
        for ((port=start_port; port<=end_port; port++)); do
            if timeout 1 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
                echo "Port $port: Open"
            fi
        done
    fi
}

connectivity_test() {
    echo "Connectivity Test"
    echo "================"
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com" "github.com")
    
    for host in "${test_hosts[@]}"; do
        echo -n "Testing $host: "
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            echo "✓ Reachable"
        else
            echo "✗ Unreachable"
        fi
    done
}

dns_lookup_interactive() {
    echo "DNS Lookup"
    echo "=========="
    
    read -p "Enter hostname to lookup: " hostname
    
    if [[ -n "$hostname" ]]; then
        show_progress "Looking up $hostname"
        
        if command_exists nslookup; then
            nslookup "$hostname"
        elif command_exists dig; then
            dig "$hostname"
        else
            show_error "No DNS lookup tools available"
        fi
    else
        show_error "Hostname required"
    fi
}

network_speed_test() {
    echo "Network Speed Test"
    echo "=================="
    
    if command_exists speedtest-cli; then
        show_progress "Running speed test"
        speedtest-cli
    else
        show_warning "speedtest-cli not available"
        echo "Install with: pip install speedtest-cli"
    fi
}

show_service_urls() {
    echo "Service URLs"
    echo "============"
    
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    
    echo "Local Access:"
    echo "  Grafana:    http://localhost:${GRAFANA_PORT:-3000}"
    echo "  Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  InfluxDB:   http://localhost:${INFLUXDB_PORT:-8086}"
    echo "  Loki:       http://localhost:${LOKI_PORT:-3100}"
    echo ""
    
    echo "Network Access:"
    echo "  Grafana:    http://$ip_address:${GRAFANA_PORT:-3000}"
    echo "  Prometheus: http://$ip_address:${PROMETHEUS_PORT:-9090}"
    echo "  InfluxDB:   http://$ip_address:${INFLUXDB_PORT:-8086}"
    echo "  Loki:       http://$ip_address:${LOKI_PORT:-3100}"
}

show_firewall_status() {
    echo "Firewall Status"
    echo "==============="
    
    if command_exists ufw; then
        echo "UFW Status:"
        sudo ufw status verbose
    elif command_exists iptables; then
        echo "iptables Rules:"
        sudo iptables -L -n
    else
        echo "No firewall tools detected"
    fi
}

# =============================================================================
# File Operation Functions
# =============================================================================

find_files_interactive() {
    echo "Find Files"
    echo "=========="
    
    read -p "Enter filename pattern: " pattern
    read -p "Enter search directory (default: current): " search_dir
    search_dir=${search_dir:-.}
    
    if [[ -n "$pattern" ]]; then
        show_progress "Searching for files matching: $pattern"
        find "$search_dir" -name "$pattern" -type f 2>/dev/null
    else
        show_error "Filename pattern required"
    fi
}

disk_usage_analysis() {
    echo "Disk Usage Analysis"
    echo "=================="
    
    echo "Top 10 largest directories:"
    du -h "$PROJECT_ROOT" 2>/dev/null | sort -hr | head -10
    
    echo ""
    echo "Top 10 largest files:"
    find "$PROJECT_ROOT" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -10
}

file_permissions_check() {
    echo "File Permissions Check"
    echo "====================="
    
    echo "Checking critical file permissions..."
    
    local critical_files=(
        ".env"
        "secrets/"
        "docker-compose.yml"
    )
    
    for file in "${critical_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        
        if [[ -e "$full_path" ]]; then
            local perms
            perms=$(stat -c "%a %n" "$full_path")
            echo "$perms"
            
            # Check for overly permissive permissions
            local perm_num
            perm_num=$(echo "$perms" | cut -d' ' -f1)
            
            if [[ "$file" == ".env" ]] && [[ "$perm_num" != "600" ]]; then
                show_warning ".env file should have 600 permissions"
            fi
            
            if [[ "$file" == "secrets/" ]] && [[ "$perm_num" != "700" ]]; then
                show_warning "secrets directory should have 700 permissions"
            fi
        else
            echo "$file: Not found"
        fi
    done
}

cleanup_temporary_files() {
    echo "Cleanup Temporary Files"
    echo "======================"
    
    show_progress "Cleaning temporary files"
    
    local temp_patterns=(
        "*.tmp"
        "*.bak"
        "*.old"
        "*~"
        ".DS_Store"
    )
    
    local cleaned_count=0
    
    for pattern in "${temp_patterns[@]}"; do
        local files
        files=$(find "$PROJECT_ROOT" -name "$pattern" -type f 2>/dev/null)
        
        if [[ -n "$files" ]]; then
            echo "$files" | while read -r file; do
                rm -f "$file"
                ((cleaned_count++))
            done
        fi
    done
    
    show_success "Cleaned $cleaned_count temporary files"
}

archive_old_files_interactive() {
    echo "Archive Old Files"
    echo "================="
    
    read -p "Enter age in days (files older than this will be archived): " age_days
    
    if [[ "$age_days" =~ ^[0-9]+$ ]] && [[ $age_days -gt 0 ]]; then
        local archive_dir="$PROJECT_ROOT/archive/$(date +%Y%m%d)"
        
        show_progress "Finding files older than $age_days days"
        
        local old_files
        old_files=$(find "$PROJECT_ROOT" -type f -mtime +"$age_days" -not -path "*/archive/*" 2>/dev/null)
        
        if [[ -n "$old_files" ]]; then
            local file_count
            file_count=$(echo "$old_files" | wc -l)
            
            echo "Found $file_count files older than $age_days days"
            read -p "Archive these files? (y/N): " confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                mkdir -p "$archive_dir"
                
                echo "$old_files" | while read -r file; do
                    local relative_path
                    relative_path=$(realpath --relative-to="$PROJECT_ROOT" "$file")
                    local archive_path="$archive_dir/$relative_path"
                    
                    mkdir -p "$(dirname "$archive_path")"
                    mv "$file" "$archive_path"
                done
                
                show_success "Archived $file_count files to $archive_dir"
            else
                show_info "Archive cancelled"
            fi
        else
            show_info "No files found older than $age_days days"
        fi
    else
        show_error "Invalid age (must be a positive number)"
    fi
}

file_integrity_check() {
    echo "File Integrity Check"
    echo "==================="
    
    local critical_files=(
        "docker-compose.yml"
        ".env.example"
        "scripts/setup.sh"
    )
    
    echo "Checking integrity of critical files..."
    
    for file in "${critical_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        
        if [[ -f "$full_path" ]]; then
            local checksum
            checksum=$(sha256sum "$full_path" | cut -d' ' -f1)
            echo "$file: $checksum"
        else
            show_warning "$file: Missing"
        fi
    done
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
    show_info "Utilities session interrupted"
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
        --help|-h)
            show_pimonitor_logo
            echo "PiMonitor Utilities Script"
            echo
            echo "Usage:"
            echo "  $0           # Interactive menu mode"
            echo "  $0 --help    # Show this help"
            echo "  $0 --version # Show version"
            echo
            echo "Available utilities:"
            echo "  - Backup Management"
            echo "  - Log Management"
            echo "  - Configuration Tools"
            echo "  - Secret Generation"
            echo "  - System Information"
            echo "  - Network Tools"
            echo "  - File Operations"
            exit 0
            ;;
        --version|-v)
            show_pimonitor_logo
            echo "Version: $UTILITIES_VERSION"
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