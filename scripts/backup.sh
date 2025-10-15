#!/bin/bash
# PiMonitor Backup Management Script
# Comprehensive backup and restore operations for PiMonitor data and configurations

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$SCRIPT_DIR/lib/docker.sh"

# =============================================================================
# Backup Configuration
# =============================================================================

readonly BACKUP_VERSION="2.0.0"
readonly BACKUP_DIR="$PROJECT_ROOT/backups"
readonly MAX_BACKUPS=10
readonly COMPRESSION_LEVEL=6

# =============================================================================
# Backup Functions
# =============================================================================

# Display backup banner
show_banner() {
    cat << 'EOF'
    ____             __                
   / __ )____ ______/ /____  ______    
  / __  / __ `/ ___/ //_/ / / / __ \   
 / /_/ / /_/ / /__/ ,< / /_/ / /_/ /   
/_____/\__,_/\___/_/|_|\__,_/ .___/    
                          /_/          
PiMonitor Backup Manager v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  create [name]     Create a new backup
  list              List available backups
  restore <name>    Restore from backup
  delete <name>     Delete a backup
  cleanup           Remove old backups (keep last $MAX_BACKUPS)
  verify <name>     Verify backup integrity
  export <name>     Export backup as compressed archive
  import <file>     Import backup from compressed archive

Options:
  -f, --force       Force operation without confirmation
  -c, --compress    Compress backup (for create command)
  -v, --verbose     Verbose output
  -h, --help        Show this help message

Examples:
  $0 create                    # Create backup with auto-generated name
  $0 create pre-update         # Create backup with custom name
  $0 list                      # List all backups
  $0 restore backup-20231215   # Restore specific backup
  $0 cleanup                   # Remove old backups
  $0 export backup-20231215    # Export backup as .tar.gz
EOF
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    BACKUP_NAME=""
    FORCE="false"
    COMPRESS="false"
    VERBOSE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            create|list|restore|delete|cleanup|verify|export|import)
                COMMAND="$1"
                shift
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -c|--compress)
                COMPRESS="true"
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
                if [[ -z "$BACKUP_NAME" ]]; then
                    BACKUP_NAME="$1"
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

# Generate backup name
generate_backup_name() {
    local prefix="${1:-backup}"
    echo "${prefix}-$(date +%Y%m%d_%H%M%S)"
}

# Create backup
create_backup() {
    local backup_name="${BACKUP_NAME:-$(generate_backup_name)}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_info "Creating backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Create backup manifest
    create_backup_manifest "$backup_path"
    
    # Backup Docker volumes
    backup_volumes "$backup_path"
    
    # Backup configurations
    backup_configurations "$backup_path"
    
    # Backup environment and settings
    backup_environment "$backup_path"
    
    # Backup logs (recent only)
    backup_logs "$backup_path"
    
    # Compress if requested
    if [[ "$COMPRESS" == "true" ]]; then
        compress_backup "$backup_path"
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    log_info "Backup created successfully: $backup_path"
}

# Create backup manifest
create_backup_manifest() {
    local backup_path="$1"
    local manifest_file="$backup_path/manifest.json"
    
    log_debug "Creating backup manifest: $manifest_file"
    
    # Get system information
    local os_info
    os_info=$(get_os_info)
    local arch
    arch=$(get_architecture)
    
    # Get Docker information
    local docker_version=""
    local compose_version=""
    if command_exists docker; then
        docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
        compose_version=$(docker compose version --short 2>/dev/null)
    fi
    
    # Get service status
    local running_services=()
    if docker compose ps --services --filter "status=running" >/dev/null 2>&1; then
        mapfile -t running_services < <(docker compose ps --services --filter "status=running")
    fi
    
    # Create JSON manifest
    cat > "$manifest_file" << EOF
{
  "backup": {
    "name": "$(basename "$backup_path")",
    "created": "$(date -Iseconds)",
    "version": "$BACKUP_VERSION",
    "type": "full"
  },
  "system": {
    "os": "$os_info",
    "architecture": "$arch",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
  },
  "docker": {
    "version": "$docker_version",
    "compose_version": "$compose_version"
  },
  "pimonitor": {
    "environment": "${ENVIRONMENT:-development}",
    "optional_services": "${INCLUDE_OPTIONAL:-false}",
    "running_services": [$(printf '"%s",' "${running_services[@]}" | sed 's/,$//')],
    "project_root": "$PROJECT_ROOT"
  },
  "contents": {
    "volumes": true,
    "configurations": true,
    "environment": true,
    "logs": true
  }
}
EOF
    
    log_debug "Backup manifest created"
}

# Backup Docker volumes
backup_volumes() {
    local backup_path="$1"
    local volumes_dir="$backup_path/volumes"
    
    log_info "Backing up Docker volumes..."
    mkdir -p "$volumes_dir"
    
    # Get list of project volumes
    local volumes
    volumes=$(list_project_volumes)
    
    if [[ -z "$volumes" ]]; then
        log_warn "No project volumes found to backup"
        return 0
    fi
    
    local volume_count=0
    for volume in $volumes; do
        log_debug "Backing up volume: $volume"
        
        if backup_volume "$volume" "$volumes_dir"; then
            ((volume_count++))
        else
            log_warn "Failed to backup volume: $volume"
        fi
    done
    
    log_info "Backed up $volume_count Docker volumes"
}

# Backup configurations
backup_configurations() {
    local backup_path="$1"
    local configs_dir="$backup_path/configs"
    
    log_info "Backing up configurations..."
    
    if [[ -d "$PROJECT_ROOT/configs" ]]; then
        cp -r "$PROJECT_ROOT/configs" "$configs_dir"
        log_debug "Copied configs directory"
    else
        log_warn "No configs directory found"
    fi
    
    # Backup Docker Compose files
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.yaml"
        "docker-compose.override.yml"
        "docker-compose.prod.yml"
        "docker-compose.optional.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$compose_file" ]]; then
            cp "$PROJECT_ROOT/$compose_file" "$backup_path/"
            log_debug "Copied $compose_file"
        fi
    done
    
    log_info "Configuration backup completed"
}

# Backup environment and settings
backup_environment() {
    local backup_path="$1"
    
    log_info "Backing up environment and settings..."
    
    # Backup .env file (without secrets)
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        # Create sanitized version without sensitive data
        grep -v -E "(PASSWORD|TOKEN|SECRET|KEY)" "$PROJECT_ROOT/.env" > "$backup_path/.env.sanitized" 2>/dev/null || true
        log_debug "Created sanitized .env backup"
    fi
    
    # Backup .env.example
    if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
        cp "$PROJECT_ROOT/.env.example" "$backup_path/"
        log_debug "Copied .env.example"
    fi
    
    # Backup PiMonitor configuration
    if [[ -f "$PROJECT_ROOT/.pimonitor-config" ]]; then
        cp "$PROJECT_ROOT/.pimonitor-config" "$backup_path/"
        log_debug "Copied .pimonitor-config"
    fi
    
    # Backup setup completion marker
    if [[ -f "$PROJECT_ROOT/.pimonitor-setup-complete" ]]; then
        cp "$PROJECT_ROOT/.pimonitor-setup-complete" "$backup_path/"
        log_debug "Copied setup completion marker"
    fi
    
    log_info "Environment backup completed"
}

# Backup recent logs
backup_logs() {
    local backup_path="$1"
    local logs_dir="$backup_path/logs"
    
    log_info "Backing up recent logs..."
    mkdir -p "$logs_dir"
    
    # Backup PiMonitor logs (last 7 days)
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        find "$PROJECT_ROOT/logs" -name "*.log" -mtime -7 -exec cp {} "$logs_dir/" \; 2>/dev/null || true
        log_debug "Copied recent log files"
    fi
    
    # Export recent Docker logs for key services
    local services=("grafana" "loki" "prometheus" "influxdb")
    for service in "${services[@]}"; do
        if is_service_running "$service"; then
            docker_compose_exec logs --tail 1000 "$service" > "$logs_dir/${service}.log" 2>/dev/null || true
            log_debug "Exported logs for $service"
        fi
    done
    
    log_info "Log backup completed"
}

# Compress backup
compress_backup() {
    local backup_path="$1"
    local compressed_file="${backup_path}.tar.gz"
    
    log_info "Compressing backup..."
    
    if tar -czf "$compressed_file" -C "$BACKUP_DIR" "$(basename "$backup_path")"; then
        rm -rf "$backup_path"
        log_info "Backup compressed: $compressed_file"
    else
        log_error "Failed to compress backup"
        return 1
    fi
}

# List backups
list_backups() {
    log_info "Available backups:"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo "No backups found"
        return 0
    fi
    
    printf "%-25s %-20s %-10s %s\n" "NAME" "CREATED" "SIZE" "TYPE"
    printf "%-25s %-20s %-10s %s\n" "----" "-------" "----" "----"
    
    # List directories (uncompressed backups)
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -o -name "*-20*" | sort | while read -r backup_dir; do
        local name
        name=$(basename "$backup_dir")
        local size
        size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
        local created=""
        local type="directory"
        
        # Try to get creation date from manifest
        if [[ -f "$backup_dir/manifest.json" ]] && command_exists jq; then
            created=$(jq -r '.backup.created' "$backup_dir/manifest.json" 2>/dev/null | cut -d'T' -f1)
        fi
        
        # Fallback to directory modification time
        if [[ -z "$created" ]]; then
            created=$(stat -c %y "$backup_dir" 2>/dev/null | cut -d' ' -f1)
        fi
        
        printf "%-25s %-20s %-10s %s\n" "$name" "$created" "$size" "$type"
    done
    
    # List compressed backups
    find "$BACKUP_DIR" -maxdepth 1 -name "*.tar.gz" | sort | while read -r backup_file; do
        local name
        name=$(basename "$backup_file" .tar.gz)
        local size
        size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
        local created
        created=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1)
        local type="compressed"
        
        printf "%-25s %-20s %-10s %s\n" "$name" "$created" "$size" "$type"
    done
}

# Restore backup
restore_backup() {
    local backup_name="$BACKUP_NAME"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name required for restore"
        echo ""
        list_backups
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    local compressed_backup="$BACKUP_DIR/${backup_name}.tar.gz"
    
    # Check if backup exists
    if [[ -d "$backup_path" ]]; then
        log_info "Found uncompressed backup: $backup_path"
    elif [[ -f "$compressed_backup" ]]; then
        log_info "Found compressed backup: $compressed_backup"
        log_info "Extracting backup..."
        
        if tar -xzf "$compressed_backup" -C "$BACKUP_DIR"; then
            log_info "Backup extracted successfully"
        else
            log_error "Failed to extract backup"
            return 1
        fi
    else
        log_error "Backup not found: $backup_name"
        echo ""
        list_backups
        return 1
    fi
    
    # Verify backup integrity
    if ! verify_backup_integrity "$backup_path"; then
        log_error "Backup integrity check failed"
        return 1
    fi
    
    # Confirm restore operation
    log_warn "This will restore data from backup: $backup_name"
    log_warn "Current data will be overwritten!"
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "Are you sure you want to continue?" "n"; then
            log_info "Restore cancelled by user"
            return 0
        fi
    fi
    
    # Stop services
    log_info "Stopping services for restore..."
    docker_compose_exec down 2>/dev/null || true
    
    # Restore volumes
    restore_volumes "$backup_path"
    
    # Restore configurations
    restore_configurations "$backup_path"
    
    # Restore environment
    restore_environment "$backup_path"
    
    log_info "Restore completed successfully"
    log_info "You may need to restart services: ./scripts/deploy.sh start"
}

# Restore volumes
restore_volumes() {
    local backup_path="$1"
    local volumes_dir="$backup_path/volumes"
    
    if [[ ! -d "$volumes_dir" ]]; then
        log_warn "No volumes to restore"
        return 0
    fi
    
    log_info "Restoring Docker volumes..."
    
    find "$volumes_dir" -name "*.tar.gz" -type f | while read -r backup_file; do
        local volume_name
        volume_name=$(basename "$backup_file" .tar.gz | sed 's/_[0-9]*_[0-9]*$//')
        
        log_debug "Restoring volume: $volume_name"
        restore_volume "$volume_name" "$backup_file"
    done
    
    log_info "Volume restore completed"
}

# Restore configurations
restore_configurations() {
    local backup_path="$1"
    
    log_info "Restoring configurations..."
    
    # Restore configs directory
    if [[ -d "$backup_path/configs" ]]; then
        if [[ -d "$PROJECT_ROOT/configs" ]]; then
            backup_file "$PROJECT_ROOT/configs"
        fi
        cp -r "$backup_path/configs" "$PROJECT_ROOT/"
        log_debug "Restored configs directory"
    fi
    
    # Restore Docker Compose files
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.yaml"
        "docker-compose.override.yml"
        "docker-compose.prod.yml"
        "docker-compose.optional.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$backup_path/$compose_file" ]]; then
            if [[ -f "$PROJECT_ROOT/$compose_file" ]]; then
                backup_file "$PROJECT_ROOT/$compose_file"
            fi
            cp "$backup_path/$compose_file" "$PROJECT_ROOT/"
            log_debug "Restored $compose_file"
        fi
    done
    
    log_info "Configuration restore completed"
}

# Restore environment
restore_environment() {
    local backup_path="$1"
    
    log_info "Restoring environment settings..."
    
    # Restore .env.example
    if [[ -f "$backup_path/.env.example" ]]; then
        cp "$backup_path/.env.example" "$PROJECT_ROOT/"
        log_debug "Restored .env.example"
    fi
    
    # Restore PiMonitor configuration
    if [[ -f "$backup_path/.pimonitor-config" ]]; then
        cp "$backup_path/.pimonitor-config" "$PROJECT_ROOT/"
        log_debug "Restored .pimonitor-config"
    fi
    
    # Restore setup completion marker
    if [[ -f "$backup_path/.pimonitor-setup-complete" ]]; then
        cp "$backup_path/.pimonitor-setup-complete" "$PROJECT_ROOT/"
        log_debug "Restored setup completion marker"
    fi
    
    log_warn "Note: Sensitive environment variables (.env) were not restored for security"
    log_warn "Please recreate your .env file or restore it manually if needed"
    
    log_info "Environment restore completed"
}

# Delete backup
delete_backup() {
    local backup_name="$BACKUP_NAME"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name required for deletion"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    local compressed_backup="$BACKUP_DIR/${backup_name}.tar.gz"
    
    local target=""
    if [[ -d "$backup_path" ]]; then
        target="$backup_path"
    elif [[ -f "$compressed_backup" ]]; then
        target="$compressed_backup"
    else
        log_error "Backup not found: $backup_name"
        return 1
    fi
    
    log_warn "This will permanently delete backup: $backup_name"
    
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "Are you sure you want to delete this backup?" "n"; then
            log_info "Deletion cancelled by user"
            return 0
        fi
    fi
    
    if rm -rf "$target"; then
        log_info "Backup deleted: $backup_name"
    else
        log_error "Failed to delete backup: $backup_name"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last $MAX_BACKUPS)..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi
    
    # Count current backups
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -maxdepth 1 \( -type d -name "backup-*" -o -name "*.tar.gz" \) | wc -l)
    
    if [[ $backup_count -le $MAX_BACKUPS ]]; then
        log_debug "No cleanup needed ($backup_count <= $MAX_BACKUPS)"
        return 0
    fi
    
    # Remove oldest backups
    local to_remove=$((backup_count - MAX_BACKUPS))
    log_info "Removing $to_remove old backups..."
    
    find "$BACKUP_DIR" -maxdepth 1 \( -type d -name "backup-*" -o -name "*.tar.gz" \) -printf '%T@ %p\n' | \
        sort -n | head -n "$to_remove" | cut -d' ' -f2- | \
        while read -r old_backup; do
            log_debug "Removing old backup: $(basename "$old_backup")"
            rm -rf "$old_backup"
        done
    
    log_info "Cleanup completed"
}

# Verify backup integrity
verify_backup_integrity() {
    local backup_path="$1"
    
    log_info "Verifying backup integrity..."
    
    # Check if manifest exists
    if [[ ! -f "$backup_path/manifest.json" ]]; then
        log_error "Backup manifest not found"
        return 1
    fi
    
    # Validate manifest JSON
    if command_exists jq; then
        if ! jq empty "$backup_path/manifest.json" 2>/dev/null; then
            log_error "Invalid backup manifest JSON"
            return 1
        fi
    fi
    
    # Check expected directories
    local expected_dirs=("volumes" "configs")
    for dir in "${expected_dirs[@]}"; do
        if [[ ! -d "$backup_path/$dir" ]]; then
            log_warn "Expected directory not found: $dir"
        fi
    done
    
    # Verify volume backups
    if [[ -d "$backup_path/volumes" ]]; then
        local volume_files
        volume_files=$(find "$backup_path/volumes" -name "*.tar.gz" | wc -l)
        log_debug "Found $volume_files volume backup files"
    fi
    
    log_info "Backup integrity verification completed"
    return 0
}

# Export backup
export_backup() {
    local backup_name="$BACKUP_NAME"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name required for export"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    local export_file="$PROJECT_ROOT/${backup_name}.tar.gz"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_name"
        return 1
    fi
    
    log_info "Exporting backup: $backup_name"
    
    if tar -czf "$export_file" -C "$BACKUP_DIR" "$backup_name"; then
        log_info "Backup exported: $export_file"
    else
        log_error "Failed to export backup"
        return 1
    fi
}

# Import backup
import_backup() {
    local import_file="$BACKUP_NAME"
    
    if [[ -z "$import_file" ]]; then
        log_error "Import file required"
        return 1
    fi
    
    if [[ ! -f "$import_file" ]]; then
        log_error "Import file not found: $import_file"
        return 1
    fi
    
    log_info "Importing backup from: $import_file"
    
    mkdir -p "$BACKUP_DIR"
    
    if tar -xzf "$import_file" -C "$BACKUP_DIR"; then
        log_info "Backup imported successfully"
    else
        log_error "Failed to import backup"
        return 1
    fi
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Show banner for interactive commands
    if [[ "$COMMAND" != "list" ]]; then
        show_banner
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Execute command
    case "$COMMAND" in
        "create")
            create_backup
            ;;
        "list")
            list_backups
            ;;
        "restore")
            restore_backup
            ;;
        "delete")
            delete_backup
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "verify")
            verify_backup_integrity "$BACKUP_DIR/$BACKUP_NAME"
            ;;
        "export")
            export_backup
            ;;
        "import")
            import_backup
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