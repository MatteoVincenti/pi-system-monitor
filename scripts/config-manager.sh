#!/bin/bash
# PiMonitor Configuration Management Script
# Advanced configuration templating, validation, and management utilities

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# Configuration Management Constants
# =============================================================================

readonly CONFIG_VERSION="2.0.0"
readonly TEMPLATE_DIR="$PROJECT_ROOT/templates"
readonly CONFIG_SCHEMA_DIR="$PROJECT_ROOT/schemas"
readonly GENERATED_CONFIG_DIR="$PROJECT_ROOT/configs/generated"

# =============================================================================
# Configuration Functions
# =============================================================================

# Display configuration manager banner
show_banner() {
    cat << 'EOF'
   ______            _____      
  / ____/___  ____  / __(_)___ _
 / /   / __ \/ __ \/ /_/ / __ `/
/ /___/ /_/ / / / / __/ / /_/ / 
\____/\____/_/ /_/_/ /_/\__, /  
                      /____/   
PiMonitor Configuration Manager v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  validate [env]        Validate configuration for environment
  generate [env]        Generate configuration files from templates
  template <service>    Create configuration template for service
  schema <service>      Create validation schema for service
  diff <env1> <env2>    Compare configurations between environments
  migrate <from> <to>   Migrate configuration from one version to another
  export <env>          Export configuration as portable package
  import <package>      Import configuration package
  check                 Check configuration health and consistency
  reset <service>       Reset service configuration to defaults

Options:
  -e, --environment ENV Environment to use (development|production|staging)
  -f, --force          Force operation without confirmation
  -v, --verbose        Verbose output with detailed information
  -o, --output FILE    Output file for export operations
  -t, --template DIR   Custom template directory
  -s, --schema FILE    Custom schema file for validation
  -h, --help           Show this help message

Examples:
  $0 validate production           # Validate production configuration
  $0 generate development          # Generate dev configs from templates
  $0 diff development production   # Compare dev vs prod configurations
  $0 export production -o prod.tar.gz  # Export production config
  $0 template grafana              # Create Grafana config template
  $0 check                         # Check all configurations
EOF
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    ENVIRONMENT=""
    SERVICE=""
    FORCE="false"
    VERBOSE="false"
    OUTPUT_FILE=""
    TEMPLATE_DIR_OVERRIDE=""
    SCHEMA_FILE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            validate|generate|template|schema|diff|migrate|export|import|check|reset)
                COMMAND="$1"
                shift
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                export LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -t|--template)
                TEMPLATE_DIR_OVERRIDE="$2"
                shift 2
                ;;
            -s|--schema)
                SCHEMA_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [[ -z "$SERVICE" ]] && [[ "$COMMAND" =~ ^(template|schema|reset)$ ]]; then
                    SERVICE="$1"
                elif [[ -z "$ENVIRONMENT" ]] && [[ "$COMMAND" =~ ^(validate|generate|export)$ ]]; then
                    ENVIRONMENT="$1"
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

# Load environment configuration
load_environment_config() {
    local env="${1:-${ENVIRONMENT:-development}}"
    local env_file="$PROJECT_ROOT/.env.$env"
    
    # Try environment-specific file first
    if [[ -f "$env_file" ]]; then
        log_debug "Loading environment config: $env_file"
        # shellcheck source=/dev/null
        set -a && source "$env_file" && set +a
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        log_debug "Loading default environment config: .env"
        # shellcheck source=/dev/null
        set -a && source "$PROJECT_ROOT/.env" && set +a
    else
        log_warn "No environment configuration found for: $env"
        return 1
    fi
    
    export ENVIRONMENT="$env"
    return 0
}

# Validate configuration for environment
validate_configuration() {
    local env="${ENVIRONMENT:-development}"
    
    log_info "Validating configuration for environment: $env"
    
    # Load environment configuration
    if ! load_environment_config "$env"; then
        log_error "Failed to load environment configuration"
        return 1
    fi
    
    # Run comprehensive validation
    local validation_errors=0
    
    # Validate environment variables
    if ! validate_environment; then
        ((validation_errors++))
    fi
    
    # Validate service configurations
    if ! validate_service_configs; then
        ((validation_errors++))
    fi
    
    # Validate port availability (skip in CI)
    if [[ "${CI:-false}" != "true" ]] && [[ "${SKIP_PORT_CHECK:-false}" != "true" ]]; then
        if ! validate_port_availability; then
            ((validation_errors++))
        fi
    fi
    
    # Validate system requirements
    validate_system_resources  # This only warns
    
    # Environment-specific validations
    case "$env" in
        "production")
            validate_production_config || ((validation_errors++))
            ;;
        "development")
            validate_development_config || ((validation_errors++))
            ;;
        "staging")
            validate_staging_config || ((validation_errors++))
            ;;
    esac
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Configuration validation failed with $validation_errors errors"
        return 1
    fi
    
    log_info "Configuration validation completed successfully"
    return 0
}

# Validate production-specific configuration
validate_production_config() {
    log_info "Validating production-specific configuration..."
    
    local errors=0
    
    # Check for default passwords
    local default_passwords=(
        "changeme"
        "admin"
        "password"
        "123456"
        "admin123"
    )
    
    for password in "${default_passwords[@]}"; do
        if [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "$password" ]] || 
           [[ "${INFLUXDB_ADMIN_PASSWORD:-}" == "$password" ]]; then
            log_error "Default password detected in production: $password"
            ((errors++))
        fi
    done
    
    # Check password strength
    if [[ ${#GRAFANA_ADMIN_PASSWORD} -lt 12 ]]; then
        log_error "Grafana admin password too short for production (minimum 12 characters)"
        ((errors++))
    fi
    
    # Check security settings
    if [[ "${GRAFANA_ALLOW_SIGN_UP:-}" == "true" ]]; then
        log_error "Sign up should be disabled in production"
        ((errors++))
    fi
    
    if [[ "${GRAFANA_ANONYMOUS_ENABLED:-}" == "true" ]]; then
        log_error "Anonymous access should be disabled in production"
        ((errors++))
    fi
    
    # Check HTTPS settings
    if [[ "${ENABLE_HTTPS:-}" != "true" ]]; then
        log_warn "HTTPS is not enabled in production"
    fi
    
    return $errors
}

# Validate development-specific configuration
validate_development_config() {
    log_info "Validating development-specific configuration..."
    
    # Development-specific checks (mostly warnings)
    if [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "admin" ]]; then
        log_warn "Using default development password"
    fi
    
    if [[ "${LOG_LEVEL:-}" != "debug" ]]; then
        log_warn "Consider using debug log level in development"
    fi
    
    return 0
}

# Validate staging-specific configuration
validate_staging_config() {
    log_info "Validating staging-specific configuration..."
    
    local errors=0
    
    # Staging should be similar to production but allow some flexibility
    if [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "admin" ]]; then
        log_warn "Consider using a stronger password in staging"
    fi
    
    return $errors
}

# Generate configuration files from templates
generate_configuration() {
    local env="${ENVIRONMENT:-development}"
    
    log_info "Generating configuration files for environment: $env"
    
    # Load environment configuration
    if ! load_environment_config "$env"; then
        log_error "Failed to load environment configuration"
        return 1
    fi
    
    # Create generated config directory
    mkdir -p "$GENERATED_CONFIG_DIR"
    
    # Generate service configurations
    local services=("grafana" "prometheus" "loki" "alloy" "telegraf" "influxdb")
    
    for service in "${services[@]}"; do
        generate_service_config "$service" "$env"
    done
    
    log_info "Configuration generation completed"
}

# Generate configuration for specific service
generate_service_config() {
    local service="$1"
    local env="$2"
    local template_file="$TEMPLATE_DIR/${service}.template"
    local output_file="$GENERATED_CONFIG_DIR/${service}-${env}.conf"
    
    if [[ ! -f "$template_file" ]]; then
        log_warn "No template found for service: $service"
        return 0
    fi
    
    log_debug "Generating config for $service from template"
    
    # Process template with environment variable substitution
    envsubst < "$template_file" > "$output_file"
    
    # Validate generated configuration
    case "$service" in
        "grafana")
            validate_grafana_config "$output_file"
            ;;
        "prometheus")
            validate_prometheus_config "$output_file"
            ;;
        "loki")
            validate_loki_config "$output_file"
            ;;
    esac
    
    log_debug "Generated configuration: $output_file"
}

# Validate Grafana configuration
validate_grafana_config() {
    local config_file="$1"
    
    # Basic INI file validation
    if ! grep -q "^\[" "$config_file"; then
        log_error "Invalid Grafana configuration format: $config_file"
        return 1
    fi
    
    return 0
}

# Validate Prometheus configuration
validate_prometheus_config() {
    local config_file="$1"
    
    # YAML validation
    if command_exists promtool; then
        if ! promtool check config "$config_file" >/dev/null 2>&1; then
            log_error "Invalid Prometheus configuration: $config_file"
            return 1
        fi
    elif ! validate_yaml_config "$config_file" "Prometheus"; then
        return 1
    fi
    
    return 0
}

# Validate Loki configuration
validate_loki_config() {
    local config_file="$1"
    
    # YAML validation
    if ! validate_yaml_config "$config_file" "Loki"; then
        return 1
    fi
    
    return 0
}

# Create configuration template
create_template() {
    local service="$SERVICE"
    
    if [[ -z "$service" ]]; then
        log_error "Service name required for template creation"
        return 1
    fi
    
    log_info "Creating configuration template for: $service"
    
    mkdir -p "$TEMPLATE_DIR"
    local template_file="$TEMPLATE_DIR/${service}.template"
    
    if [[ -f "$template_file" ]] && [[ "$FORCE" != "true" ]]; then
        log_error "Template already exists: $template_file"
        log_info "Use --force to overwrite"
        return 1
    fi
    
    # Create service-specific template
    case "$service" in
        "grafana")
            create_grafana_template "$template_file"
            ;;
        "prometheus")
            create_prometheus_template "$template_file"
            ;;
        "loki")
            create_loki_template "$template_file"
            ;;
        "alloy")
            create_alloy_template "$template_file"
            ;;
        "telegraf")
            create_telegraf_template "$template_file"
            ;;
        "influxdb")
            create_influxdb_template "$template_file"
            ;;
        *)
            log_error "Unknown service: $service"
            return 1
            ;;
    esac
    
    log_info "Template created: $template_file"
}

# Create Grafana configuration template
create_grafana_template() {
    local template_file="$1"
    
    cat > "$template_file" << 'EOF'
# Grafana Configuration Template
# Generated by PiMonitor Configuration Manager

[server]
protocol = http
http_addr = 0.0.0.0
http_port = ${GRAFANA_PORT}
domain = ${GRAFANA_DOMAIN}
root_url = ${GRAFANA_ROOT_URL}
serve_from_sub_path = ${GRAFANA_SERVE_FROM_SUB_PATH}

[security]
admin_user = ${GRAFANA_ADMIN_USER}
admin_password = ${GRAFANA_ADMIN_PASSWORD}
disable_gravatar = ${GRAFANA_DISABLE_GRAVATAR}
cookie_secure = ${GRAFANA_COOKIE_SECURE}
cookie_samesite = ${GRAFANA_COOKIE_SAMESITE}
content_type_protection = ${GRAFANA_CONTENT_TYPE_PROTECTION}
x_content_type_options = ${GRAFANA_X_CONTENT_TYPE_OPTIONS}
x_xss_protection = ${GRAFANA_X_XSS_PROTECTION}

[users]
allow_sign_up = ${GRAFANA_ALLOW_SIGN_UP}
allow_org_create = ${GRAFANA_ALLOW_ORG_CREATE}
auto_assign_org = ${GRAFANA_AUTO_ASSIGN_ORG}
auto_assign_org_role = ${GRAFANA_AUTO_ASSIGN_ORG_ROLE}

[auth.anonymous]
enabled = ${GRAFANA_ANONYMOUS_ENABLED}
org_name = ${GRAFANA_ANONYMOUS_ORG_NAME}
org_role = ${GRAFANA_ANONYMOUS_ORG_ROLE}

[log]
mode = ${GRAFANA_LOG_MODE}
level = ${GRAFANA_LOG_LEVEL}
filters = ${GRAFANA_LOG_FILTERS}

[feature_toggles]
enable = ${GRAFANA_FEATURE_TOGGLES}

[plugins]
enable_alpha = ${GRAFANA_PLUGIN_ADMIN_ENABLED}
allow_loading_unsigned_plugins = ${GRAFANA_PLUGIN_ADMIN_EXTERNAL_MANAGE_ENABLED}
EOF
}

# Create Prometheus configuration template
create_prometheus_template() {
    local template_file="$1"
    
    cat > "$template_file" << 'EOF'
# Prometheus Configuration Template
# Generated by PiMonitor Configuration Manager

global:
  scrape_interval: ${PROMETHEUS_SCRAPE_INTERVAL}
  evaluation_interval: ${PROMETHEUS_EVALUATION_INTERVAL}
  external_labels:
    cluster: 'pimonitor'
    environment: '${ENVIRONMENT}'

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:${GRAFANA_PORT}']

  - job_name: 'influxdb'
    static_configs:
      - targets: ['influxdb:${INFLUXDB_PORT}']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:${LOKI_PORT}']

  - job_name: 'alloy'
    static_configs:
      - targets: ['alloy:${ALLOY_PORT}']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: ${TELEGRAF_INTERVAL}
EOF
}

# Create Loki configuration template
create_loki_template() {
    local template_file="$1"
    
    cat > "$template_file" << 'EOF'
# Loki Configuration Template
# Generated by PiMonitor Configuration Manager

auth_enabled: false

server:
  http_listen_port: ${LOKI_HTTP_PORT}
  grpc_listen_port: ${LOKI_GRPC_PORT}
  log_level: ${LOKI_LOG_LEVEL}
  log_format: ${LOKI_LOG_FORMAT}

common:
  path_prefix: ${LOKI_STORAGE_PATH}
  storage:
    filesystem:
      chunks_directory: ${LOKI_STORAGE_PATH}/chunks
      rules_directory: ${LOKI_STORAGE_PATH}/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

limits_config:
  retention_period: ${LOKI_RETENTION_PERIOD}
  ingestion_rate_mb: ${LOKI_INGESTION_RATE_MB}
  ingestion_burst_size_mb: ${LOKI_INGESTION_BURST_SIZE_MB}
  max_streams_per_user: ${LOKI_MAX_STREAMS_PER_USER}
  max_line_size: ${LOKI_MAX_LINE_SIZE}
  max_query_parallelism: ${LOKI_MAX_QUERY_PARALLELISM}
  max_query_series: ${LOKI_MAX_QUERY_SERIES}

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: ${LOKI_STORAGE_PATH}/boltdb-shipper-active
    cache_location: ${LOKI_STORAGE_PATH}/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: ${LOKI_STORAGE_PATH}/chunks

compactor:
  working_directory: ${LOKI_STORAGE_PATH}/compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
EOF
}

# Create Alloy configuration template
create_alloy_template() {
    local template_file="$1"
    
    cat > "$template_file" << 'EOF'
// Alloy Configuration Template
// Generated by PiMonitor Configuration Manager

logging {
  level  = "${ALLOY_LOG_LEVEL}"
  format = "logfmt"
}

// System logs collection
loki.source.file "system_logs" {
  targets = [
    {__path__ = "/var/log/syslog", job = "syslog"},
    {__path__ = "/var/log/auth.log", job = "auth"},
  ]
  forward_to = [loki.write.default.receiver]
}

// Docker container logs
loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = []
  forward_to = [loki.write.default.receiver]
}

// Loki output
loki.write "default" {
  endpoint {
    url = "${ALLOY_LOKI_ENDPOINT}"
  }
  external_labels = {
    cluster = "pimonitor"
    environment = "${ENVIRONMENT}"
  }
}

// Prometheus metrics
prometheus.exporter.self "alloy" {}

prometheus.scrape "alloy" {
  targets    = prometheus.exporter.self.alloy.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

prometheus.remote_write "default" {
  endpoint {
    url = "${ALLOY_PROMETHEUS_ENDPOINT}"
  }
}
EOF
}

# Create Telegraf configuration template
create_telegraf_template() {
    local template_file="$1"
    
    cat > "$template_file" << 'EOF'
# Telegraf Configuration Template
# Generated by PiMonitor Configuration Manager

[global_tags]
  environment = "${ENVIRONMENT}"
  cluster = "pimonitor"

[agent]
  interval = "${TELEGRAF_INTERVAL}"
  round_interval = ${TELEGRAF_ROUND_INTERVAL}
  metric_batch_size = ${TELEGRAF_METRIC_BATCH_SIZE}
  metric_buffer_limit = ${TELEGRAF_METRIC_BUFFER_LIMIT}
  collection_jitter = "${TELEGRAF_COLLECTION_JITTER}"
  flush_interval = "${TELEGRAF_FLUSH_INTERVAL}"
  flush_jitter = "${TELEGRAF_FLUSH_JITTER}"
  precision = "${TELEGRAF_PRECISION}"
  hostname = "${TELEGRAF_HOSTNAME}"
  omit_hostname = false
  debug = ${TELEGRAF_DEBUG}
  quiet = ${TELEGRAF_QUIET}

# Output to InfluxDB
[[outputs.influxdb_v2]]
  urls = ["http://influxdb:${INFLUXDB_PORT}"]
  token = "${INFLUXDB_ADMIN_TOKEN}"
  organization = "${INFLUXDB_INIT_ORG}"
  bucket = "${INFLUXDB_INIT_BUCKET}"

# Output to Prometheus
[[outputs.prometheus_client]]
  listen = ":${TELEGRAF_PORT}"
  metric_version = 2

# System metrics
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.swap]]

[[inputs.system]]

[[inputs.net]]

[[inputs.netstat]]

# Docker metrics
[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"
  gather_services = false
  container_names = []
  source_tag = false
  container_name_include = []
  container_name_exclude = []
  timeout = "5s"
  docker_label_include = []
  docker_label_exclude = []
  tag_env = ["JAVA_HOME", "HEAP_SIZE"]
  perdevice = true
  total = false
EOF
}

# Create InfluxDB configuration template
create_influxdb_template() {
    local template_file="$1"
    
    cat > "$template_file" << 'EOF'
# InfluxDB Configuration Template
# Generated by PiMonitor Configuration Manager

[meta]
  dir = "/var/lib/influxdb2/meta"

[data]
  dir = "/var/lib/influxdb2/data"
  engine = "tsm1"
  wal-dir = "/var/lib/influxdb2/wal"

[coordinator]
  write-timeout = "10s"
  max-concurrent-queries = ${INFLUXDB_QUERY_CONCURRENCY}
  query-timeout = "0s"
  log-queries-after = "0s"
  max-select-point = 0
  max-select-series = 0
  max-select-buckets = 0

[retention]
  enabled = true
  check-interval = "30m0s"

[shard-precreation]
  enabled = true
  check-interval = "10m0s"
  advance-period = "30m0s"

[monitor]
  store-enabled = true
  store-database = "_internal"
  store-interval = "10s"

[subscriber]
  enabled = true
  http-timeout = "30s"
  insecure-skip-verify = false
  ca-certs = ""
  write-concurrency = 40
  write-buffer-size = 1000

[http]
  enabled = true
  bind-address = ":${INFLUXDB_PORT}"
  auth-enabled = false
  log-enabled = true
  write-tracing = false
  pprof-enabled = true
  debug-pprof-enabled = false
  https-enabled = false
  https-certificate = "/etc/ssl/influxdb.pem"
  https-private-key = ""
  max-row-limit = 0
  max-connection-limit = 0
  shared-secret = ""
  realm = "InfluxDB"
  unix-socket-enabled = false
  bind-socket = "/var/run/influxdb.sock"
  max-body-size = 25000000
  access-log-path = ""
  max-concurrent-write-limit = 0
  max-enqueued-write-limit = 0
  enqueued-write-timeout = 30000000000

[logging]
  format = "auto"
  level = "${INFLUXDB_LOG_LEVEL}"
  suppress-logo = false
EOF
}

# Compare configurations between environments
compare_configurations() {
    local env1="$1"
    local env2="$2"
    
    if [[ -z "$env1" ]] || [[ -z "$env2" ]]; then
        log_error "Two environment names required for comparison"
        return 1
    fi
    
    log_info "Comparing configurations: $env1 vs $env2"
    
    local env1_file="$PROJECT_ROOT/.env.$env1"
    local env2_file="$PROJECT_ROOT/.env.$env2"
    
    if [[ ! -f "$env1_file" ]]; then
        log_error "Environment file not found: $env1_file"
        return 1
    fi
    
    if [[ ! -f "$env2_file" ]]; then
        log_error "Environment file not found: $env2_file"
        return 1
    fi
    
    echo "Configuration Differences:"
    echo "=========================="
    
    if command_exists diff; then
        diff -u "$env1_file" "$env2_file" || true
    else
        log_warn "diff command not available, showing basic comparison"
        echo "Environment 1 ($env1):"
        cat "$env1_file"
        echo ""
        echo "Environment 2 ($env2):"
        cat "$env2_file"
    fi
}

# Check configuration health
check_configuration_health() {
    log_info "Checking configuration health and consistency..."
    
    local issues=0
    
    # Check for required files
    local required_files=(
        ".env.example"
        "docker-compose.yml"
        "configs/grafana"
        "configs/prometheus"
        "configs/loki"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$PROJECT_ROOT/$file" ]]; then
            log_error "Required file/directory missing: $file"
            ((issues++))
        fi
    done
    
    # Check environment files
    local env_files=(".env.development" ".env.production" ".env.staging")
    for env_file in "${env_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$env_file" ]]; then
            log_debug "Found environment file: $env_file"
            
            # Basic syntax check
            if ! bash -n "$PROJECT_ROOT/$env_file" 2>/dev/null; then
                log_error "Syntax error in environment file: $env_file"
                ((issues++))
            fi
        fi
    done
    
    # Check for common configuration issues
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        # Check for default passwords
        if grep -q "changeme" "$PROJECT_ROOT/.env"; then
            log_warn "Default passwords detected in .env file"
        fi
        
        # Check for missing required variables
        local required_vars=("GRAFANA_PORT" "INFLUXDB_PORT" "PROMETHEUS_PORT")
        for var in "${required_vars[@]}"; do
            if ! grep -q "^$var=" "$PROJECT_ROOT/.env"; then
                log_error "Required variable missing from .env: $var"
                ((issues++))
            fi
        done
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_info "Configuration health check passed"
    else
        log_error "Configuration health check found $issues issues"
        return 1
    fi
}

# Export configuration package
export_configuration() {
    local env="${ENVIRONMENT:-development}"
    local output_file="${OUTPUT_FILE:-pimonitor-config-${env}-$(date +%Y%m%d_%H%M%S).tar.gz}"
    
    log_info "Exporting configuration for environment: $env"
    
    local temp_dir="/tmp/pimonitor-config-$$"
    mkdir -p "$temp_dir"
    
    # Copy environment files
    cp "$PROJECT_ROOT/.env.example" "$temp_dir/"
    if [[ -f "$PROJECT_ROOT/.env.$env" ]]; then
        cp "$PROJECT_ROOT/.env.$env" "$temp_dir/"
    fi
    
    # Copy configuration directories
    if [[ -d "$PROJECT_ROOT/configs" ]]; then
        cp -r "$PROJECT_ROOT/configs" "$temp_dir/"
    fi
    
    # Copy Docker Compose files
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.override.yml"
        "docker-compose.prod.yml"
        "docker-compose.optional.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$compose_file" ]]; then
            cp "$PROJECT_ROOT/$compose_file" "$temp_dir/"
        fi
    done
    
    # Create export manifest
    {
        echo "PiMonitor Configuration Export"
        echo "============================="
        echo "Environment: $env"
        echo "Exported: $(date)"
        echo "Version: $CONFIG_VERSION"
    } > "$temp_dir/MANIFEST.txt"
    
    # Create archive
    if tar -czf "$output_file" -C "$temp_dir" .; then
        log_info "Configuration exported: $output_file"
    else
        log_error "Failed to export configuration"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Show banner for interactive commands
    show_banner
    
    # Create necessary directories
    mkdir -p "$TEMPLATE_DIR" "$CONFIG_SCHEMA_DIR" "$GENERATED_CONFIG_DIR"
    
    # Execute command
    case "$COMMAND" in
        "validate")
            validate_configuration
            ;;
        "generate")
            generate_configuration
            ;;
        "template")
            create_template
            ;;
        "diff")
            compare_configurations "$ENVIRONMENT" "$SERVICE"
            ;;
        "check")
            check_configuration_health
            ;;
        "export")
            export_configuration
            ;;
        *)
            log_error "Command not yet implemented: $COMMAND"
            return 1
            ;;
    esac
}

# Run main function
main "$@"