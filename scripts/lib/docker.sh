#!/bin/bash
# Docker-specific utilities and functions for PiMonitor scripts
# This library provides Docker operations, validations, and management functions

# Strict error handling
set -euo pipefail

# =============================================================================
# Docker Configuration
# =============================================================================

# Docker network configuration
readonly DOCKER_NETWORK="${COMPOSE_PROJECT_NAME:-pimonitor}_skynet"
readonly LOKI_PLUGIN_NAME="loki"

# Required Docker versions
readonly MIN_DOCKER_VERSION="20.10.0"
readonly MIN_COMPOSE_VERSION="2.0.0"

# =============================================================================
# Docker Validation Functions
# =============================================================================

# Check if Docker is installed and running
validate_docker() {
    log_debug "Validating Docker installation..."
    
    if ! command_exists docker; then
        log_error "Docker is not installed"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        log_info "Try: sudo systemctl start docker"
        return 1
    fi
    
    # Check Docker version
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0.0.0")
    
    if ! version_compare "$docker_version" "$MIN_DOCKER_VERSION"; then
        log_error "Docker version $docker_version is too old (minimum: $MIN_DOCKER_VERSION)"
        return 1
    fi
    
    log_info "Docker $docker_version is installed and running"
    return 0
}

# Check if Docker Compose is available
validate_docker_compose() {
    log_debug "Validating Docker Compose installation..."
    
    # Check for Docker Compose v2 (docker compose)
    if docker compose version >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "0.0.0")
        
        if version_compare "$compose_version" "$MIN_COMPOSE_VERSION"; then
            log_info "Docker Compose $compose_version is available"
            return 0
        else
            log_error "Docker Compose version $compose_version is too old (minimum: $MIN_COMPOSE_VERSION)"
            return 1
        fi
    fi
    
    # Check for legacy docker-compose
    if command_exists docker-compose; then
        log_warn "Found legacy docker-compose, but Docker Compose v2 is required"
        log_info "Please install Docker Compose v2: https://docs.docker.com/compose/install/"
        return 1
    fi
    
    log_error "Docker Compose is not installed"
    return 1
}

# Validate Docker plugins
validate_docker_plugins() {
    log_debug "Validating Docker plugins..."
    
    # Check for Loki plugin
    if ! docker plugin ls --format '{{.Name}}' | grep -q "^$LOKI_PLUGIN_NAME:"; then
        log_error "Loki Docker plugin is not installed"
        log_info "Install with: docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions"
        return 1
    fi
    
    # Check if plugin is enabled
    if ! docker plugin ls --format '{{.Name}}\t{{.Enabled}}' | grep "^$LOKI_PLUGIN_NAME:" | grep -q "true"; then
        log_error "Loki Docker plugin is not enabled"
        log_info "Enable with: docker plugin enable $LOKI_PLUGIN_NAME"
        return 1
    fi
    
    log_info "Required Docker plugins are installed and enabled"
    return 0
}

# Validate Docker system resources
validate_docker_system() {
    log_debug "Validating Docker system resources..."
    
    # Check available disk space
    local available_space
    available_space=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
    local required_space=$((10 * 1024 * 1024)) # 10GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_warn "Low disk space: $(($available_space / 1024 / 1024))GB available, 10GB recommended"
    fi
    
    # Check available memory
    local available_memory
    available_memory=$(free -k | awk 'NR==2 {print $7}')
    local required_memory=$((2 * 1024 * 1024)) # 2GB in KB
    
    if [[ $available_memory -lt $required_memory ]]; then
        log_warn "Low memory: $(($available_memory / 1024 / 1024))GB available, 2GB recommended"
    fi
    
    log_info "Docker system resources validated"
    return 0
}

# Validate architecture support
validate_architecture() {
    log_debug "Validating architecture support..."
    
    local arch
    arch=$(get_architecture)
    
    case "$arch" in
        "x86_64"|"amd64"|"aarch64"|"arm64")
            log_info "Architecture $arch is supported"
            return 0
            ;;
        *)
            log_error "Architecture $arch is not officially supported"
            log_warn "PiMonitor is designed for x86_64 and ARM64 architectures"
            return 1
            ;;
    esac
}

# =============================================================================
# Docker Compose Operations
# =============================================================================

# Execute docker compose command with proper file selection
docker_compose_exec() {
    local compose_files=("-f" "docker-compose.yml")
    
    # Add environment-specific compose file
    case "${ENVIRONMENT:-development}" in
        "production")
            if [[ -f "docker-compose.prod.yml" ]]; then
                compose_files+=("-f" "docker-compose.prod.yml")
            fi
            ;;
        "development")
            if [[ -f "docker-compose.override.yml" ]]; then
                compose_files+=("-f" "docker-compose.override.yml")
            fi
            ;;
    esac
    
    # Add optional services if requested
    if [[ "${INCLUDE_OPTIONAL:-false}" == "true" ]]; then
        if [[ -f "docker-compose.optional.yml" ]]; then
            compose_files+=("-f" "docker-compose.optional.yml")
        fi
        # Legacy compose files have been migrated to docker-compose.optional.yml
    fi
    
    log_debug "Executing: docker compose ${compose_files[*]} $*"
    docker compose "${compose_files[@]}" "$@"
}

# Validate Docker Compose configuration
validate_compose_config() {
    log_debug "Validating Docker Compose configuration..."
    
    if docker_compose_exec config >/dev/null 2>&1; then
        log_info "Docker Compose configuration is valid"
        return 0
    else
        log_error "Docker Compose configuration is invalid"
        log_info "Run 'docker compose config' to see detailed errors"
        return 1
    fi
}

# =============================================================================
# Service Management Functions
# =============================================================================

# Wait for service to be healthy
wait_for_service_health() {
    local service="$1"
    local timeout="${2:-120}"
    local interval="${3:-5}"
    
    log_info "Waiting for $service to be healthy (timeout: ${timeout}s)"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        local status
        status=$(docker_compose_exec ps --format json "$service" 2>/dev/null | jq -r '.[0].Health // "unknown"' 2>/dev/null || echo "unknown")
        
        case "$status" in
            "healthy")
                log_info "$service is healthy"
                return 0
                ;;
            "unhealthy")
                log_warn "$service is unhealthy"
                ;;
            "starting")
                log_debug "$service is starting..."
                ;;
            *)
                # Check if container is running (for services without health checks)
                local state
                state=$(docker_compose_exec ps --format json "$service" 2>/dev/null | jq -r '.[0].State // "unknown"' 2>/dev/null || echo "unknown")
                if [[ "$state" == "running" ]]; then
                    log_info "$service is running"
                    return 0
                fi
                ;;
        esac
        
        sleep "$interval"
        ((count += interval))
    done
    
    log_error "Timeout waiting for $service to be healthy"
    return 1
}

# Get service status
get_service_status() {
    local service="$1"
    
    docker_compose_exec ps --format json "$service" 2>/dev/null | jq -r '.[0].State // "unknown"' 2>/dev/null || echo "unknown"
}

# Get service health
get_service_health() {
    local service="$1"
    
    docker_compose_exec ps --format json "$service" 2>/dev/null | jq -r '.[0].Health // "unknown"' 2>/dev/null || echo "unknown"
}

# =============================================================================
# Network Management Functions
# =============================================================================

# Ensure Docker network exists
ensure_docker_network() {
    local network_name="$1"
    
    if docker network ls --format '{{.Name}}' | grep -q "^$network_name$"; then
        log_debug "Docker network $network_name already exists"
        return 0
    fi
    
    log_info "Creating Docker network: $network_name"
    if docker network create "$network_name" >/dev/null; then
        log_info "Docker network $network_name created successfully"
        return 0
    else
        log_error "Failed to create Docker network: $network_name"
        return 1
    fi
}

# Remove Docker network
remove_docker_network() {
    local network_name="$1"
    
    if ! docker network ls --format '{{.Name}}' | grep -q "^$network_name$"; then
        log_debug "Docker network $network_name does not exist"
        return 0
    fi
    
    log_info "Removing Docker network: $network_name"
    if docker network rm "$network_name" >/dev/null 2>&1; then
        log_info "Docker network $network_name removed successfully"
        return 0
    else
        log_warn "Failed to remove Docker network: $network_name (may be in use)"
        return 1
    fi
}

# =============================================================================
# Volume Management Functions
# =============================================================================

# List Docker volumes for the project
list_project_volumes() {
    local project_name="${COMPOSE_PROJECT_NAME:-pimonitor}"
    docker volume ls --format '{{.Name}}' | grep "^${project_name}_" || true
}

# Backup Docker volume
backup_volume() {
    local volume_name="$1"
    local backup_path="$2"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    
    log_info "Backing up volume $volume_name to $backup_path"
    
    mkdir -p "$backup_path"
    
    if docker run --rm \
        -v "$volume_name:/data:ro" \
        -v "$backup_path:/backup" \
        alpine tar czf "/backup/${volume_name}_${timestamp}.tar.gz" -C /data .; then
        log_info "Volume backup completed: ${volume_name}_${timestamp}.tar.gz"
        return 0
    else
        log_error "Failed to backup volume: $volume_name"
        return 1
    fi
}

# Restore Docker volume
restore_volume() {
    local volume_name="$1"
    local backup_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_info "Restoring volume $volume_name from $backup_file"
    
    if docker run --rm \
        -v "$volume_name:/data" \
        -v "$(dirname "$backup_file"):/backup" \
        alpine tar xzf "/backup/$(basename "$backup_file")" -C /data; then
        log_info "Volume restore completed: $volume_name"
        return 0
    else
        log_error "Failed to restore volume: $volume_name"
        return 1
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Compare version strings
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Remove 'v' prefix if present
    version1=${version1#v}
    version2=${version2#v}
    
    # Use sort -V for version comparison
    if printf '%s\n%s\n' "$version1" "$version2" | sort -V -C 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get Docker Compose project name
get_compose_project_name() {
    echo "${COMPOSE_PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
}

# Clean up Docker resources
cleanup_docker_resources() {
    log_info "Cleaning up Docker resources..."
    
    # Remove stopped containers
    docker container prune -f >/dev/null 2>&1 || true
    
    # Remove unused networks
    docker network prune -f >/dev/null 2>&1 || true
    
    # Remove unused images (be careful with this)
    if confirm "Remove unused Docker images?" "n"; then
        docker image prune -f >/dev/null 2>&1 || true
    fi
    
    log_info "Docker cleanup completed"
}

# =============================================================================
# Initialization
# =============================================================================

# Initialize Docker library
init_docker() {
    log_debug "Initializing Docker library"
    
    # Ensure we're in the project root
    if [[ ! -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in project root: $PROJECT_ROOT"
        return 1
    fi
    
    log_debug "Docker library initialized"
}

# Auto-initialize if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_docker
fi