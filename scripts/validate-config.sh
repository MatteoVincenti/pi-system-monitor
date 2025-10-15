#!/bin/bash
# PiMonitor Configuration Validation Script
# Comprehensive validation using schemas and custom rules

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# Validation Configuration
# =============================================================================

readonly VALIDATION_VERSION="2.0.0"
readonly SCHEMA_DIR="$PROJECT_ROOT/schemas"
readonly VALIDATION_REPORT_DIR="$PROJECT_ROOT/validation-reports"

# =============================================================================
# Advanced Validation Functions
# =============================================================================

# Display validation banner
show_banner() {
    cat << 'EOF'
 _   __      ___     __      __  _           
| | / /___ _/ (_)___/ /___ _/ /_(_)___  ____ 
| |/ / __ `/ / / __  / __ `/ __/ / __ \/ __ \
|   / /_/ / / / /_/ / /_/ / /_/ / /_/ / / / /
|__/\__,_/_/_/\__,_/\__,_/\__/_/\____/_/ /_/ 
                                             
PiMonitor Configuration Validator v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [environment] [options]

Arguments:
  environment          Environment to validate (development|production|staging|all)

Options:
  -s, --strict         Strict validation mode (fail on warnings)
  -r, --report FILE    Generate detailed validation report
  -f, --fix            Attempt to fix common issues automatically
  -c, --check-only     Only check syntax, skip comprehensive validation
  -v, --verbose        Verbose output with detailed information
  -h, --help           Show this help message

Examples:
  $0 production                    # Validate production environment
  $0 all -r validation-report.html # Validate all environments with report
  $0 development --fix             # Validate and fix development config
  $0 --check-only                  # Quick syntax check only
EOF
}

# Parse command line arguments
parse_args() {
    ENVIRONMENT=""
    STRICT_MODE="false"
    REPORT_FILE=""
    FIX_ISSUES="false"
    CHECK_ONLY="false"
    VERBOSE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            development|production|staging|all)
                ENVIRONMENT="$1"
                shift
                ;;
            -s|--strict)
                STRICT_MODE="true"
                shift
                ;;
            -r|--report)
                REPORT_FILE="$2"
                shift 2
                ;;
            -f|--fix)
                FIX_ISSUES="true"
                shift
                ;;
            -c|--check-only)
                CHECK_ONLY="true"
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
    
    # Default to all environments if none specified
    ENVIRONMENT="${ENVIRONMENT:-all}"
}

# Validate environment configuration with schema
validate_with_schema() {
    local env="$1"
    local env_file="$PROJECT_ROOT/.env.$env"
    local schema_file="$SCHEMA_DIR/environment-schema.json"
    
    log_info "Validating $env environment with schema..."
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    if [[ ! -f "$schema_file" ]]; then
        log_warn "Schema file not found: $schema_file"
        return 0
    fi
    
    # Convert .env to JSON for validation
    local temp_json="/tmp/env-${env}-$$.json"
    convert_env_to_json "$env_file" "$temp_json"
    
    # Validate with schema if jq is available
    if command_exists jq; then
        validate_json_with_schema "$temp_json" "$schema_file" "$env"
    else
        log_warn "jq not available, skipping schema validation"
    fi
    
    # Cleanup
    rm -f "$temp_json"
}

# Convert .env file to JSON
convert_env_to_json() {
    local env_file="$1"
    local json_file="$2"
    
    echo "{" > "$json_file"
    
    local first_entry=true
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove quotes from value
        value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
        
        # Add comma for all but first entry
        if [[ "$first_entry" == "true" ]]; then
            first_entry=false
        else
            echo "," >> "$json_file"
        fi
        
        # Convert boolean and numeric values
        if [[ "$value" =~ ^(true|false)$ ]]; then
            echo "  \"$key\": $value" >> "$json_file"
        elif [[ "$value" =~ ^[0-9]+$ ]]; then
            echo "  \"$key\": $value" >> "$json_file"
        else
            echo "  \"$key\": \"$value\"" >> "$json_file"
        fi
    done < <(grep -v '^#' "$env_file" | grep '=')
    
    echo "}" >> "$json_file"
}

# Validate JSON against schema
validate_json_with_schema() {
    local json_file="$1"
    local schema_file="$2"
    local env="$3"
    
    log_debug "Validating JSON against schema..."
    
    # Basic JSON validation
    if ! jq empty "$json_file" 2>/dev/null; then
        log_error "Invalid JSON generated from environment file"
        return 1
    fi
    
    # Load schema and validate required fields
    local required_fields
    required_fields=$(jq -r '.required[]' "$schema_file" 2>/dev/null)
    
    local validation_errors=0
    
    # Check required fields
    while read -r field; do
        if ! jq -e "has(\"$field\")" "$json_file" >/dev/null 2>&1; then
            log_error "Required field missing: $field"
            ((validation_errors++))
        fi
    done <<< "$required_fields"
    
    # Environment-specific validation
    if [[ "$env" == "production" ]]; then
        validate_production_schema "$json_file" "$schema_file" || ((validation_errors++))
    fi
    
    return $validation_errors
}

# Validate production-specific schema requirements
validate_production_schema() {
    local json_file="$1"
    local schema_file="$2"
    
    log_debug "Validating production-specific requirements..."
    
    local errors=0
    
    # Check for forbidden values in production
    local forbidden_passwords=("admin" "password" "changeme" "123456")
    local grafana_password
    grafana_password=$(jq -r '.GRAFANA_ADMIN_PASSWORD // empty' "$json_file")
    
    for forbidden in "${forbidden_passwords[@]}"; do
        if [[ "$grafana_password" == "$forbidden" ]]; then
            log_error "Forbidden password in production: $forbidden"
            ((errors++))
        fi
    done
    
    # Check boolean security settings
    local allow_signup
    allow_signup=$(jq -r '.GRAFANA_ALLOW_SIGN_UP // false' "$json_file")
    if [[ "$allow_signup" == "true" ]]; then
        log_error "Sign up should be disabled in production"
        ((errors++))
    fi
    
    local anonymous_enabled
    anonymous_enabled=$(jq -r '.GRAFANA_ANONYMOUS_ENABLED // false' "$json_file")
    if [[ "$anonymous_enabled" == "true" ]]; then
        log_error "Anonymous access should be disabled in production"
        ((errors++))
    fi
    
    return $errors
}

# Validate Docker Compose files
validate_compose_files() {
    log_info "Validating Docker Compose files..."
    
    local compose_files=(
        "docker-compose.yml"
        "docker-compose.override.yml"
        "docker-compose.prod.yml"
        "docker-compose.optional.yml"
    )
    
    local validation_errors=0
    
    for compose_file in "${compose_files[@]}"; do
        local file_path="$PROJECT_ROOT/$compose_file"
        
        if [[ -f "$file_path" ]]; then
            log_debug "Validating: $compose_file"
            
            # YAML syntax validation
            if ! validate_yaml_config "$file_path" "Docker Compose"; then
                ((validation_errors++))
                continue
            fi
            
            # Docker Compose specific validation
            if command_exists docker; then
                if ! docker compose -f "$file_path" config >/dev/null 2>&1; then
                    log_error "Docker Compose validation failed: $compose_file"
                    ((validation_errors++))
                fi
            fi
            
            # Check for security issues
            validate_compose_security "$file_path" || ((validation_errors++))
        fi
    done
    
    return $validation_errors
}

# Validate Docker Compose security settings
validate_compose_security() {
    local compose_file="$1"
    
    local security_issues=0
    
    # Check for privileged containers
    if grep -q "privileged.*true" "$compose_file"; then
        log_warn "Privileged container detected in: $(basename "$compose_file")"
        if [[ "$STRICT_MODE" == "true" ]]; then
            ((security_issues++))
        fi
    fi
    
    # Check for host network mode
    if grep -q "network_mode.*host" "$compose_file"; then
        log_warn "Host network mode detected in: $(basename "$compose_file")"
        if [[ "$STRICT_MODE" == "true" ]]; then
            ((security_issues++))
        fi
    fi
    
    # Check for root user
    if grep -q "user.*root" "$compose_file"; then
        log_warn "Root user detected in: $(basename "$compose_file")"
        if [[ "$STRICT_MODE" == "true" ]]; then
            ((security_issues++))
        fi
    fi
    
    return $security_issues
}

# Validate service configurations
validate_service_configurations() {
    log_info "Validating service configurations..."
    
    local validation_errors=0
    
    # Validate each service config
    local services=("grafana" "prometheus" "loki" "alloy" "telegraf" "influxdb")
    
    for service in "${services[@]}"; do
        case "$service" in
            "grafana")
                validate_grafana_configuration || ((validation_errors++))
                ;;
            "prometheus")
                validate_prometheus_configuration || ((validation_errors++))
                ;;
            "loki")
                validate_loki_configuration || ((validation_errors++))
                ;;
            "alloy")
                validate_alloy_configuration || ((validation_errors++))
                ;;
            "telegraf")
                validate_telegraf_configuration || ((validation_errors++))
                ;;
            "influxdb")
                validate_influxdb_configuration || ((validation_errors++))
                ;;
        esac
    done
    
    return $validation_errors
}

# Validate Grafana configuration
validate_grafana_configuration() {
    local config_dir="$PROJECT_ROOT/configs/grafana"
    
    if [[ ! -d "$config_dir" ]]; then
        log_warn "Grafana configuration directory not found"
        return 0
    fi
    
    # Check provisioning configurations
    local provisioning_dir="$config_dir/provisioning"
    if [[ -d "$provisioning_dir" ]]; then
        # Validate datasource configurations
        find "$provisioning_dir/datasources" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read -r datasource_file; do
            validate_yaml_config "$datasource_file" "Grafana Datasource" || return 1
        done
        
        # Validate dashboard configurations
        find "$provisioning_dir/dashboards" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read -r dashboard_config; do
            validate_yaml_config "$dashboard_config" "Grafana Dashboard Config" || return 1
        done
    fi
    
    # Validate dashboard JSON files
    find "$config_dir/dashboards" -name "*.json" 2>/dev/null | while read -r dashboard_file; do
        validate_json_config "$dashboard_file" "Grafana Dashboard" || return 1
    done
    
    return 0
}

# Validate Prometheus configuration
validate_prometheus_configuration() {
    local config_file="$PROJECT_ROOT/configs/prometheus/prometheus.yml"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Prometheus configuration file not found"
        return 0
    fi
    
    # YAML validation
    if ! validate_yaml_config "$config_file" "Prometheus"; then
        return 1
    fi
    
    # Prometheus-specific validation
    if command_exists promtool; then
        if ! promtool check config "$config_file" >/dev/null 2>&1; then
            log_error "Prometheus configuration validation failed"
            return 1
        fi
    fi
    
    return 0
}

# Validate Loki configuration
validate_loki_configuration() {
    local config_file="$PROJECT_ROOT/configs/loki/loki.yml"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Loki configuration file not found"
        return 0
    fi
    
    # YAML validation
    if ! validate_yaml_config "$config_file" "Loki"; then
        return 1
    fi
    
    return 0
}

# Validate Alloy configuration
validate_alloy_configuration() {
    local config_file="$PROJECT_ROOT/configs/alloy/config.alloy"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Alloy configuration file not found"
        return 0
    fi
    
    # Basic syntax check (Alloy uses HCL-like syntax)
    if ! validate_config_file "$config_file" "Alloy"; then
        return 1
    fi
    
    return 0
}

# Validate Telegraf configuration
validate_telegraf_configuration() {
    local config_file="$PROJECT_ROOT/configs/telegraf/telegraf.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Telegraf configuration file not found"
        return 0
    fi
    
    # Basic file validation
    if ! validate_config_file "$config_file" "Telegraf"; then
        return 1
    fi
    
    return 0
}

# Validate InfluxDB configuration
validate_influxdb_configuration() {
    local config_dir="$PROJECT_ROOT/configs/influxdb"
    
    if [[ ! -d "$config_dir" ]]; then
        log_warn "InfluxDB configuration directory not found"
        return 0
    fi
    
    # Check for configuration files
    find "$config_dir" -name "*.conf" -o -name "*.toml" 2>/dev/null | while read -r config_file; do
        validate_config_file "$config_file" "InfluxDB" || return 1
    done
    
    return 0
}

# Fix common configuration issues
fix_configuration_issues() {
    log_info "Attempting to fix common configuration issues..."
    
    local fixes_applied=0
    
    # Fix file permissions
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        chmod 600 "$PROJECT_ROOT/.env"
        log_info "Fixed .env file permissions"
        ((fixes_applied++))
    fi
    
    # Fix secrets directory permissions
    if [[ -d "$PROJECT_ROOT/secrets" ]]; then
        chmod 700 "$PROJECT_ROOT/secrets"
        chmod 600 "$PROJECT_ROOT/secrets"/*.txt 2>/dev/null || true
        log_info "Fixed secrets directory permissions"
        ((fixes_applied++))
    fi
    
    # Create missing directories
    local required_dirs=(
        "configs/grafana/provisioning/datasources"
        "configs/grafana/provisioning/dashboards"
        "configs/grafana/provisioning/alerting"
        "configs/grafana/dashboards"
        "configs/prometheus/rules"
        "data"
        "logs"
        "backups"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            mkdir -p "$PROJECT_ROOT/$dir"
            log_info "Created missing directory: $dir"
            ((fixes_applied++))
        fi
    done
    
    log_info "Applied $fixes_applied configuration fixes"
}

# Generate validation report
generate_validation_report() {
    local report_file="${REPORT_FILE:-$VALIDATION_REPORT_DIR/validation-$(date +%Y%m%d_%H%M%S).html}"
    
    log_info "Generating validation report: $report_file"
    
    mkdir -p "$(dirname "$report_file")"
    
    # Generate HTML report
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PiMonitor Configuration Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .error { color: #d32f2f; }
        .warning { color: #f57c00; }
        .success { color: #388e3c; }
        .info { color: #1976d2; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>PiMonitor Configuration Validation Report</h1>
        <p>Generated: $(date)</p>
        <p>Version: $VALIDATION_VERSION</p>
    </div>
EOF
    
    # Add validation results to report
    echo "<div class='section'>" >> "$report_file"
    echo "<h2>Validation Summary</h2>" >> "$report_file"
    
    # Run validation and capture results
    local temp_log="/tmp/validation-log-$$.txt"
    
    if validate_all_environments > "$temp_log" 2>&1; then
        echo "<p class='success'>✓ All validations passed</p>" >> "$report_file"
    else
        echo "<p class='error'>✗ Validation failed</p>" >> "$report_file"
    fi
    
    echo "<pre>$(cat "$temp_log")</pre>" >> "$report_file"
    echo "</div>" >> "$report_file"
    
    # Close HTML
    echo "</body></html>" >> "$report_file"
    
    rm -f "$temp_log"
    
    log_info "Validation report generated: $report_file"
}

# Validate all environments
validate_all_environments() {
    local environments=("development" "production" "staging")
    local total_errors=0
    
    for env in "${environments[@]}"; do
        log_info "Validating environment: $env"
        
        if [[ -f "$PROJECT_ROOT/.env.$env" ]]; then
            validate_with_schema "$env" || ((total_errors++))
        else
            log_warn "Environment file not found: .env.$env"
        fi
    done
    
    # Validate common configurations
    validate_compose_files || ((total_errors++))
    validate_service_configurations || ((total_errors++))
    
    return $total_errors
}

# Quick syntax check
quick_syntax_check() {
    log_info "Performing quick syntax check..."
    
    local syntax_errors=0
    
    # Check .env files
    find "$PROJECT_ROOT" -name ".env*" -type f | while read -r env_file; do
        if ! bash -n "$env_file" 2>/dev/null; then
            log_error "Syntax error in: $(basename "$env_file")"
            ((syntax_errors++))
        fi
    done
    
    # Check YAML files
    find "$PROJECT_ROOT/configs" -name "*.yml" -o -name "*.yaml" 2>/dev/null | while read -r yaml_file; do
        if command_exists yq; then
            if ! yq eval '.' "$yaml_file" >/dev/null 2>&1; then
                log_error "YAML syntax error in: $(basename "$yaml_file")"
                ((syntax_errors++))
            fi
        fi
    done
    
    # Check JSON files
    find "$PROJECT_ROOT/configs" -name "*.json" 2>/dev/null | while read -r json_file; do
        if command_exists jq; then
            if ! jq empty "$json_file" 2>/dev/null; then
                log_error "JSON syntax error in: $(basename "$json_file")"
                ((syntax_errors++))
            fi
        fi
    done
    
    if [[ $syntax_errors -eq 0 ]]; then
        log_info "Syntax check passed"
    else
        log_error "Syntax check found $syntax_errors errors"
        return 1
    fi
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
    mkdir -p "$VALIDATION_REPORT_DIR"
    
    # Quick syntax check mode
    if [[ "$CHECK_ONLY" == "true" ]]; then
        quick_syntax_check
        return $?
    fi
    
    # Fix issues if requested
    if [[ "$FIX_ISSUES" == "true" ]]; then
        fix_configuration_issues
    fi
    
    # Run validation
    local validation_result=0
    
    if [[ "$ENVIRONMENT" == "all" ]]; then
        validate_all_environments || validation_result=1
    else
        validate_with_schema "$ENVIRONMENT" || validation_result=1
        validate_compose_files || validation_result=1
        validate_service_configurations || validation_result=1
    fi
    
    # Generate report if requested
    if [[ -n "$REPORT_FILE" ]]; then
        generate_validation_report
    fi
    
    # Summary
    if [[ $validation_result -eq 0 ]]; then
        log_info "Configuration validation completed successfully"
    else
        log_error "Configuration validation failed"
        if [[ "$STRICT_MODE" == "true" ]]; then
            exit 1
        fi
    fi
    
    return $validation_result
}

# Run main function
main "$@"