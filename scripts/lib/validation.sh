#!/bin/bash
# Validation utilities and functions for PiMonitor scripts
# This library provides configuration and environment validation functions

# Strict error handling
set -euo pipefail

# =============================================================================
# Environment Validation
# =============================================================================

# Validate environment file
validate_environment() {
    log_debug "Validating environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    # Source environment file
    # shellcheck source=/dev/null
    source "$env_file"
    
    local errors=0
    
    # Validate required variables
    local required_vars=(
        "GRAFANA_ADMIN_PASSWORD"
        "DOCKER_INFLUXDB_INIT_ADMIN_TOKEN"
        "DOCKER_INFLUXDB_INIT_PASSWORD"
        "DOCKER_INFLUXDB_INIT_ORG"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: $var"
            ((errors++))
        fi
    done
    
    # Validate port numbers
    local port_vars=(
        "GRAFANA_PORT"
        "INFLUXDB_PORT"
        "PROMETHEUS_PORT"
        "LOKI_PORT"
        "ALLOY_PORT"
    )
    
    for var in "${port_vars[@]}"; do
        local port="${!var:-}"
        if [[ -n "$port" ]] && ! validate_port "$port"; then
            log_error "Invalid port number for $var: $port"
            ((errors++))
        fi
    done
    
    # Validate password strength
    if ! validate_password_strength "${GRAFANA_ADMIN_PASSWORD:-}"; then
        log_warn "Grafana admin password is weak (should be at least 12 characters)"
    fi
    
    if ! validate_password_strength "${DOCKER_INFLUXDB_INIT_PASSWORD:-}"; then
        log_warn "InfluxDB admin password is weak (should be at least 12 characters)"
    fi
    
    # Validate token format
    if ! validate_token_format "${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN:-}"; then
        log_error "InfluxDB admin token has invalid format (should be 64 hex characters)"
        ((errors++))
    fi
    
    # Validate organization name
    if ! validate_organization_name "${DOCKER_INFLUXDB_INIT_ORG:-}"; then
        log_error "InfluxDB organization name is invalid"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        return 1
    fi
    
    log_info "Environment validation passed"
    return 0
}

# Validate port availability
validate_port_availability() {
    log_debug "Validating port availability..."
    
    # Source environment file
    local env_file="$PROJECT_ROOT/.env"
    if [[ -f "$env_file" ]]; then
        # shellcheck source=/dev/null
        source "$env_file"
    fi
    
    local ports=(
        "${GRAFANA_PORT:-3000}"
        "${INFLUXDB_PORT:-8086}"
        "${PROMETHEUS_PORT:-9090}"
        "${LOKI_PORT:-3100}"
        "${ALLOY_PORT:-12345}"
    )
    
    local conflicts=0
    
    for port in "${ports[@]}"; do
        if ! is_port_available "$port"; then
            log_error "Port $port is already in use"
            ((conflicts++))
        fi
    done
    
    if [[ $conflicts -gt 0 ]]; then
        log_error "Port validation failed with $conflicts conflicts"
        log_info "Use 'netstat -tuln | grep :PORT' to check what's using the ports"
        return 1
    fi
    
    log_info "All required ports are available"
    return 0
}

# =============================================================================
# Configuration File Validation
# =============================================================================

# Validate service configuration files
validate_service_configs() {
    log_debug "Validating service configuration files..."
    
    local errors=0
    
    # Validate Grafana configuration
    if ! validate_grafana_config; then
        ((errors++))
    fi
    
    # Validate Prometheus configuration
    if ! validate_prometheus_config; then
        ((errors++))
    fi
    
    # Validate Loki configuration
    if ! validate_loki_config; then
        ((errors++))
    fi
    
    # Validate Alloy configuration
    if ! validate_alloy_config; then
        ((errors++))
    fi
    
    # Validate Telegraf configuration
    if ! validate_telegraf_config; then
        ((errors++))
    fi
    
    # Validate InfluxDB configuration
    if ! validate_influxdb_config; then
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Service configuration validation failed with $errors errors"
        return 1
    fi
    
    log_info "Service configuration validation passed"
    return 0
}

# Validate Grafana configuration
validate_grafana_config() {
    local config_file="$PROJECT_ROOT/configs/grafana/grafana.ini"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Grafana configuration file not found: $config_file"
        return 0  # Optional file
    fi
    
    # Basic syntax validation
    if ! grep -q "^\[server\]" "$config_file"; then
        log_error "Grafana configuration missing [server] section"
        return 1
    fi
    
    log_debug "Grafana configuration is valid"
    return 0
}

# Validate Prometheus configuration
validate_prometheus_config() {
    local config_file="$PROJECT_ROOT/configs/prometheus/prometheus.yml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Prometheus configuration file not found: $config_file"
        return 1
    fi
    
    # Validate YAML syntax
    if ! validate_yaml_syntax "$config_file"; then
        log_error "Prometheus configuration has invalid YAML syntax"
        return 1
    fi
    
    # Check for required sections
    if ! grep -q "^global:" "$config_file"; then
        log_error "Prometheus configuration missing global section"
        return 1
    fi
    
    if ! grep -q "^scrape_configs:" "$config_file"; then
        log_error "Prometheus configuration missing scrape_configs section"
        return 1
    fi
    
    log_debug "Prometheus configuration is valid"
    return 0
}

# Validate Loki configuration
validate_loki_config() {
    local config_file="$PROJECT_ROOT/configs/loki/loki.yml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Loki configuration file not found: $config_file"
        return 1
    fi
    
    # Validate YAML syntax
    if ! validate_yaml_syntax "$config_file"; then
        log_error "Loki configuration has invalid YAML syntax"
        return 1
    fi
    
    # Check for required sections
    if ! grep -q "^server:" "$config_file"; then
        log_error "Loki configuration missing server section"
        return 1
    fi
    
    if ! grep -q "^ingester:" "$config_file"; then
        log_error "Loki configuration missing ingester section"
        return 1
    fi
    
    log_debug "Loki configuration is valid"
    return 0
}

# Validate Alloy configuration
validate_alloy_config() {
    local config_file="$PROJECT_ROOT/configs/alloy/config.alloy"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Alloy configuration file not found: $config_file"
        return 1
    fi
    
    # Basic syntax validation (check for required blocks)
    if ! grep -q "loki.write" "$config_file"; then
        log_error "Alloy configuration missing loki.write block"
        return 1
    fi
    
    log_debug "Alloy configuration is valid"
    return 0
}

# Validate Telegraf configuration
validate_telegraf_config() {
    local config_file="$PROJECT_ROOT/configs/telegraf/telegraf.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Telegraf configuration file not found: $config_file"
        return 1
    fi
    
    # Check for required sections
    if ! grep -q "^\[agent\]" "$config_file"; then
        log_error "Telegraf configuration missing [agent] section"
        return 1
    fi
    
    if ! grep -q "^\[\[outputs\." "$config_file"; then
        log_error "Telegraf configuration missing output plugins"
        return 1
    fi
    
    if ! grep -q "^\[\[inputs\." "$config_file"; then
        log_error "Telegraf configuration missing input plugins"
        return 1
    fi
    
    log_debug "Telegraf configuration is valid"
    return 0
}

# Validate InfluxDB configuration
validate_influxdb_config() {
    local config_file="$PROJECT_ROOT/configs/influxdb/influxdb.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "InfluxDB configuration file not found: $config_file"
        return 0  # Optional file
    fi
    
    # Basic syntax validation
    if ! grep -q "^\[http\]" "$config_file"; then
        log_warn "InfluxDB configuration missing [http] section"
    fi
    
    log_debug "InfluxDB configuration is valid"
    return 0
}

# =============================================================================
# Data Validation Functions
# =============================================================================

# Validate port number
validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi
    
    return 0
}

# Validate password strength
validate_password_strength() {
    local password="$1"
    
    # Minimum length check
    if [[ ${#password} -lt 12 ]]; then
        return 1
    fi
    
    # Check for at least one number, one letter
    if [[ ! "$password" =~ [0-9] ]] || [[ ! "$password" =~ [a-zA-Z] ]]; then
        return 1
    fi
    
    return 0
}

# Validate token format (hex string)
validate_token_format() {
    local token="$1"
    
    # Should be 64 hex characters
    if [[ ! "$token" =~ ^[a-fA-F0-9]{64}$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate organization name
validate_organization_name() {
    local org_name="$1"
    
    # Should not be empty and contain valid characters
    if [[ -z "$org_name" ]]; then
        return 1
    fi
    
    # Should not contain special characters that could cause issues
    if [[ "$org_name" =~ [^a-zA-Z0-9_-] ]]; then
        return 1
    fi
    
    return 0
}

# Validate YAML syntax
validate_yaml_syntax() {
    local yaml_file="$1"
    
    if command_exists python3; then
        python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null
    elif command_exists python; then
        python -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null
    else
        # Fallback: basic syntax check
        if grep -q $'^\t' "$yaml_file"; then
            log_warn "YAML file contains tabs (should use spaces): $yaml_file"
            return 1
        fi
        return 0
    fi
}

# =============================================================================
# System Validation Functions
# =============================================================================

# Validate system requirements
validate_system_requirements() {
    log_debug "Validating system requirements..."
    
    local errors=0
    
    # Check available memory
    local available_memory
    available_memory=$(free -m | awk 'NR==2{print $7}')
    local required_memory=2048  # 2GB in MB
    
    if [[ $available_memory -lt $required_memory ]]; then
        log_error "Insufficient memory: ${available_memory}MB available, ${required_memory}MB required"
        ((errors++))
    fi
    
    # Check available disk space
    local available_space
    available_space=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
    local required_space=$((10 * 1024 * 1024)) # 10GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space: $(($available_space / 1024 / 1024))GB available, 10GB required"
        ((errors++))
    fi
    
    # Check for required system commands
    local required_commands=("curl" "wget" "openssl" "netstat" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command not found: $cmd"
            ((errors++))
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log_error "System requirements validation failed with $errors errors"
        return 1
    fi
    
    log_info "System requirements validation passed"
    return 0
}

# Validate network connectivity
validate_network_connectivity() {
    log_debug "Validating network connectivity..."
    
    local test_urls=(
        "https://registry-1.docker.io"
        "https://github.com"
        "https://grafana.com"
    )
    
    local failures=0
    
    for url in "${test_urls[@]}"; do
        if ! curl -s --connect-timeout 10 --max-time 30 "$url" >/dev/null; then
            log_warn "Cannot reach $url"
            ((failures++))
        fi
    done
    
    if [[ $failures -eq ${#test_urls[@]} ]]; then
        log_error "No network connectivity detected"
        return 1
    elif [[ $failures -gt 0 ]]; then
        log_warn "Some network connectivity issues detected ($failures/${#test_urls[@]} failed)"
    fi
    
    log_info "Network connectivity validation passed"
    return 0
}

# =============================================================================
# Security Validation Functions
# =============================================================================

# Validate file permissions
validate_file_permissions() {
    log_debug "Validating file permissions..."
    
    local errors=0
    
    # Check secrets directory permissions
    local secrets_dir="$PROJECT_ROOT/secrets"
    if [[ -d "$secrets_dir" ]]; then
        local perms
        perms=$(stat -c "%a" "$secrets_dir" 2>/dev/null || stat -f "%A" "$secrets_dir" 2>/dev/null || echo "unknown")
        
        if [[ "$perms" != "700" ]]; then
            log_error "Secrets directory has incorrect permissions: $perms (should be 700)"
            ((errors++))
        fi
        
        # Check individual secret files
        for secret_file in "$secrets_dir"/*.txt; do
            if [[ -f "$secret_file" ]]; then
                local file_perms
                file_perms=$(stat -c "%a" "$secret_file" 2>/dev/null || stat -f "%A" "$secret_file" 2>/dev/null || echo "unknown")
                
                if [[ "$file_perms" != "600" ]]; then
                    log_error "Secret file has incorrect permissions: $secret_file ($file_perms, should be 600)"
                    ((errors++))
                fi
            fi
        done
    fi
    
    # Check configuration file permissions
    local config_files=(
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/configs/grafana/grafana.ini"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            local file_perms
            file_perms=$(stat -c "%a" "$config_file" 2>/dev/null || stat -f "%A" "$config_file" 2>/dev/null || echo "unknown")
            
            # Configuration files should not be world-readable
            if [[ "$file_perms" =~ [0-9][0-9][4-7] ]]; then
                log_warn "Configuration file is world-readable: $config_file ($file_perms)"
            fi
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        log_error "File permissions validation failed with $errors errors"
        return 1
    fi
    
    log_info "File permissions validation passed"
    return 0
}

# =============================================================================
# Initialization
# =============================================================================

# Initialize validation library
init_validation() {
    log_debug "Initializing validation library"
    
    # Ensure required directories exist
    mkdir -p "$PROJECT_ROOT/logs"
    
    log_debug "Validation library initialized"
}

# Auto-initialize if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_validation
fi