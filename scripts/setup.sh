#!/bin/bash
# PiMonitor Setup Script
# Comprehensive setup and validation for PiMonitor observability stack

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$SCRIPT_DIR/lib/docker.sh"
# shellcheck source=./lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# Setup Configuration
# =============================================================================

readonly SETUP_VERSION="2.0.0"
readonly MIN_DOCKER_VERSION="20.10.0"
readonly MIN_COMPOSE_VERSION="2.0.0"

# =============================================================================
# Setup Functions
# =============================================================================

# Display setup banner
show_banner() {
    cat << 'EOF'
    ____  _ __  __            _ __            
   / __ \(_) /_/ /_____  ____(_) /_____  _____
  / /_/ / / __/ __/ __ \/ ___/ / __/ __ \/ ___/
 / ____/ / /_/ /_/ /_/ / /  / / /_/ /_/ / /    
/_/   /_/\__/\__/\____/_/  /_/\__/\____/_/     
                                               
PiMonitor Setup Script v2.0.0
Comprehensive Docker-based observability stack
EOF
    echo ""
    log_info "Starting PiMonitor setup process..."
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking system prerequisites..."
    
    local errors=0
    
    # Check operating system
    local os_info
    os_info=$(get_os_info)
    log_info "Operating System: $os_info"
    
    # Check architecture
    if ! validate_architecture; then
        ((errors++))
    fi
    
    # Check if running as root (not recommended)
    if is_root; then
        log_warn "Running as root is not recommended for security reasons"
        if ! confirm "Continue anyway?" "n"; then
            log_error "Setup cancelled by user"
            exit 1
        fi
    fi
    
    # Check required commands
    local required_commands=("curl" "wget" "openssl" "netstat")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command not found: $cmd"
            ((errors++))
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log_error "Prerequisites check failed with $errors errors"
        return 1
    fi
    
    log_info "Prerequisites check passed"
    return 0
}

# Setup Docker and Docker Compose
setup_docker() {
    log_info "Setting up Docker environment..."
    
    # Validate Docker installation
    if ! validate_docker; then
        log_error "Docker validation failed"
        
        if confirm "Would you like to install Docker?" "y"; then
            install_docker
        else
            log_error "Docker is required for PiMonitor. Setup cancelled."
            exit 1
        fi
    fi
    
    # Validate Docker Compose
    if ! validate_docker_compose; then
        log_error "Docker Compose validation failed"
        log_error "Please install Docker Compose v2"
        exit 1
    fi
    
    # Validate Docker plugins
    if ! validate_docker_plugins; then
        log_warn "Required Docker plugins are missing"
        
        if confirm "Would you like to install the Loki Docker plugin?" "y"; then
            install_loki_plugin
        else
            log_error "Loki Docker plugin is required for log aggregation"
            exit 1
        fi
    fi
    
    # Validate Docker system
    validate_docker_system
    
    log_info "Docker environment setup completed"
}

# Install Docker (basic installation)
install_docker() {
    log_info "Installing Docker..."
    
    local os_type
    os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os_type" in
        "linux")
            if command_exists apt-get; then
                # Debian/Ubuntu
                log_info "Installing Docker on Debian/Ubuntu..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker "$USER"
                rm get-docker.sh
            elif command_exists yum; then
                # RHEL/CentOS
                log_info "Installing Docker on RHEL/CentOS..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker "$USER"
                rm get-docker.sh
            else
                log_error "Unsupported Linux distribution for automatic Docker installation"
                log_error "Please install Docker manually: https://docs.docker.com/get-docker/"
                exit 1
            fi
            ;;
        "darwin")
            log_error "Please install Docker Desktop for macOS: https://docs.docker.com/desktop/mac/install/"
            exit 1
            ;;
        *)
            log_error "Unsupported operating system for automatic Docker installation: $os_type"
            exit 1
            ;;
    esac
    
    log_info "Docker installation completed"
    log_warn "Please log out and log back in for group changes to take effect"
}

# Install Loki Docker plugin
install_loki_plugin() {
    log_info "Installing Loki Docker plugin..."
    
    local arch
    arch=$(get_architecture)
    local plugin_tag="latest"
    
    # Use ARM64 specific tag for ARM systems
    case "$arch" in
        "aarch64"|"arm64")
            plugin_tag="3.3.2-arm64"
            ;;
        "x86_64"|"amd64")
            plugin_tag="latest"
            ;;
        *)
            log_warn "Unknown architecture $arch, using latest plugin tag"
            ;;
    esac
    
    if docker plugin install "grafana/loki-docker-driver:$plugin_tag" --alias loki --grant-all-permissions; then
        log_info "Loki Docker plugin installed successfully"
    else
        log_error "Failed to install Loki Docker plugin"
        exit 1
    fi
}

# Setup environment configuration
setup_environment() {
    log_info "Setting up environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env"
    local env_example="$PROJECT_ROOT/.env.example"
    
    # Check if .env file exists
    if [[ -f "$env_file" ]]; then
        log_info "Environment file already exists: $env_file"
        
        if confirm "Would you like to backup and recreate the .env file?" "n"; then
            backup_file "$env_file"
            cp "$env_example" "$env_file"
            log_info "Created new .env file from template"
        else
            log_info "Using existing .env file"
        fi
    else
        if [[ -f "$env_example" ]]; then
            cp "$env_example" "$env_file"
            log_info "Created .env file from template"
        else
            log_error "No .env.example template found"
            exit 1
        fi
    fi
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        log_info "Please edit $env_file and run setup again"
        exit 1
    fi
    
    log_info "Environment configuration completed"
}

# Generate security credentials
setup_security() {
    log_info "Setting up security credentials..."
    
    local secrets_dir="$PROJECT_ROOT/secrets"
    mkdir -p "$secrets_dir"
    
    # Generate secrets if they don't exist
    if [[ ! -f "$secrets_dir/grafana_admin_password.txt" ]] || 
       [[ ! -f "$secrets_dir/influxdb_admin_token.txt" ]]; then
        
        log_info "Generating security credentials..."
        "$SCRIPT_DIR/generate-secrets.sh"
    else
        log_info "Security credentials already exist"
    fi
    
    # Set proper permissions
    chmod 700 "$secrets_dir"
    chmod 600 "$secrets_dir"/*.txt 2>/dev/null || true
    
    log_info "Security setup completed"
}

# Setup project directories
setup_directories() {
    log_info "Setting up project directories..."
    
    local directories=(
        "$PROJECT_ROOT/data"
        "$PROJECT_ROOT/logs"
        "$PROJECT_ROOT/backups"
        "$PROJECT_ROOT/backups/volumes"
        "$PROJECT_ROOT/backups/configs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_debug "Created directory: $dir"
        fi
    done
    
    # Set proper permissions for data directory
    chmod 755 "$PROJECT_ROOT/data"
    
    log_info "Directory setup completed"
}

# Validate configuration files
validate_configurations() {
    log_info "Validating configuration files..."
    
    if ! validate_service_configs; then
        log_error "Configuration validation failed"
        return 1
    fi
    
    log_info "Configuration validation completed"
}

# Setup Docker network
setup_network() {
    log_info "Setting up Docker network..."
    
    ensure_docker_network "$DOCKER_NETWORK"
    
    log_info "Docker network setup completed"
}

# Interactive service selection
select_services() {
    log_info "Configuring services to deploy..."
    
    echo ""
    echo "Select deployment environment:"
    local environment
    environment=$(select_option "Choose environment:" "Development" "Production" "Custom")
    
    case "$environment" in
        "Development")
            export ENVIRONMENT="development"
            export INCLUDE_OPTIONAL="false"
            log_info "Selected development environment"
            ;;
        "Production")
            export ENVIRONMENT="production"
            export INCLUDE_OPTIONAL="false"
            log_info "Selected production environment"
            ;;
        "Custom")
            echo ""
            if confirm "Include optional services (Portainer, Watchtower)?" "n"; then
                export INCLUDE_OPTIONAL="true"
            else
                export INCLUDE_OPTIONAL="false"
            fi
            
            echo ""
            local env_choice
            env_choice=$(select_option "Choose base environment:" "Development" "Production")
            case "$env_choice" in
                "Development") export ENVIRONMENT="development" ;;
                "Production") export ENVIRONMENT="production" ;;
            esac
            ;;
    esac
    
    # Save configuration
    {
        echo "# PiMonitor deployment configuration"
        echo "# Generated by setup script on $(date)"
        echo "ENVIRONMENT=$ENVIRONMENT"
        echo "INCLUDE_OPTIONAL=$INCLUDE_OPTIONAL"
    } > "$PROJECT_ROOT/.pimonitor-config"
    
    log_info "Service configuration saved"
}

# Perform initial deployment
initial_deployment() {
    log_info "Performing initial deployment..."
    
    # Pull images first
    log_info "Pulling Docker images..."
    if ! docker_compose_exec pull; then
        log_error "Failed to pull Docker images"
        return 1
    fi
    
    # Start services
    log_info "Starting services..."
    if ! docker_compose_exec up -d; then
        log_error "Failed to start services"
        return 1
    fi
    
    # Wait for services to be healthy
    local core_services=("loki" "influxdb" "prometheus" "grafana")
    for service in "${core_services[@]}"; do
        if ! wait_for_service_health "$service" 180; then
            log_warn "Service $service did not become healthy within timeout"
        fi
    done
    
    log_info "Initial deployment completed"
}

# Display setup summary
show_summary() {
    log_info "Setup completed successfully!"
    
    echo ""
    echo "==================================="
    echo "PiMonitor Setup Summary"
    echo "==================================="
    echo "Environment: ${ENVIRONMENT:-development}"
    echo "Optional Services: ${INCLUDE_OPTIONAL:-false}"
    echo ""
    echo "Service URLs:"
    echo "  Grafana:    http://localhost:${GRAFANA_PORT:-3000}"
    echo "  Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  InfluxDB:   http://localhost:${INFLUXDB_PORT:-8086}"
    echo "  Loki:       http://localhost:${LOKI_PORT:-3100}"
    echo "  Alloy:      http://localhost:${ALLOY_PORT:-12345}"
    
    if [[ "${INCLUDE_OPTIONAL:-false}" == "true" ]]; then
        echo "  Portainer:  https://localhost:9443"
    fi
    
    echo ""
    echo "Default Credentials:"
    if [[ -f "$PROJECT_ROOT/secrets/grafana_admin_password.txt" ]]; then
        echo "  Grafana Admin: admin / $(cat "$PROJECT_ROOT/secrets/grafana_admin_password.txt")"
    fi
    
    echo ""
    echo "Next Steps:"
    echo "  1. Access Grafana at http://localhost:${GRAFANA_PORT:-3000}"
    echo "  2. Import additional dashboards if needed"
    echo "  3. Configure alerting rules"
    echo "  4. Review logs: docker compose logs -f"
    echo ""
    echo "Management Commands:"
    echo "  Start:   ./scripts/deploy.sh start"
    echo "  Stop:    ./scripts/deploy.sh stop"
    echo "  Status:  ./scripts/deploy.sh status"
    echo "  Logs:    ./scripts/logs.sh"
    echo ""
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f get-docker.sh 2>/dev/null || true
}

# =============================================================================
# Main Setup Process
# =============================================================================

main() {
    # Initialize
    show_banner
    
    # Check if already set up
    if [[ -f "$PROJECT_ROOT/.pimonitor-setup-complete" ]]; then
        log_warn "PiMonitor appears to be already set up"
        if ! confirm "Do you want to run setup again?" "n"; then
            log_info "Setup cancelled by user"
            exit 0
        fi
    fi
    
    # Run setup steps
    check_prerequisites || exit 1
    setup_docker || exit 1
    setup_directories || exit 1
    setup_environment || exit 1
    setup_security || exit 1
    validate_configurations || exit 1
    setup_network || exit 1
    select_services || exit 1
    
    # Ask before deployment
    echo ""
    if confirm "Proceed with initial deployment?" "y"; then
        initial_deployment || exit 1
    else
        log_info "Skipping initial deployment"
        log_info "Run './scripts/deploy.sh start' when ready to deploy"
    fi
    
    # Mark setup as complete
    touch "$PROJECT_ROOT/.pimonitor-setup-complete"
    
    # Show summary
    show_summary
    
    log_info "PiMonitor setup completed successfully!"
}

# Run main function
main "$@"