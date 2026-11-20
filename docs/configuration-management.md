# Configuration Management Guide

PiMonitor includes a comprehensive configuration management system that provides advanced templating, validation, and deployment automation capabilities. This guide covers all aspects of the configuration management system.

## Overview

The Configuration Manager (`scripts/config-manager.sh`) is a powerful tool that helps manage PiMonitor configurations across different environments with features including:

- **Environment-specific validation** with security checks
- **Template-based configuration** generation
- **Configuration comparison** and health monitoring
- **Portable configuration** export/import
- **Service-specific templates** for all monitoring components

## Quick Start

### Basic Usage

```bash
# Validate current configuration
./scripts/config-manager.sh validate

# Check configuration health
./scripts/config-manager.sh check

# Generate configurations from templates
./scripts/config-manager.sh generate development
```

### Environment-Specific Operations

```bash
# Validate production configuration
./scripts/config-manager.sh validate production

# Compare development vs production
./scripts/config-manager.sh diff development production

# Export production configuration
./scripts/config-manager.sh export production -o prod-config.tar.gz
```

## Command Reference

### Core Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| `validate` | `validate [environment]` | Validate configuration for specific environment |
| `generate` | `generate [environment]` | Generate configuration files from templates |
| `check` | `check` | Check configuration health and consistency |
| `diff` | `diff <env1> <env2>` | Compare configurations between environments |
| `export` | `export <env> [options]` | Export configuration as portable package |
| `template` | `template <service>` | Create configuration template for service |

### Command Options

| Option | Description | Example |
|--------|-------------|---------|
| `-e, --environment ENV` | Specify environment | `-e production` |
| `-f, --force` | Force operation without confirmation | `-f` |
| `-v, --verbose` | Enable verbose output | `-v` |
| `-o, --output FILE` | Specify output file | `-o config.tar.gz` |
| `-h, --help` | Show help message | `-h` |

## Configuration Validation

### Environment-Specific Validation

The configuration manager provides different validation rules based on the target environment:

#### Production Environment
- **Security Enforcement**: Requires strong passwords (minimum 12 characters)
- **Feature Restrictions**: Disables sign-up, anonymous access, and debug features
- **HTTPS Validation**: Warns if HTTPS is not enabled
- **Default Password Detection**: Fails if default passwords are detected

```bash
# Production validation example
./scripts/config-manager.sh validate production

# Sample output:
[INFO] Validating configuration for environment: production
[ERROR] Grafana admin password too short for production (minimum 12 characters)
[ERROR] Sign up should be disabled in production
[WARN] HTTPS is not enabled in production
[ERROR] Configuration validation failed with 2 errors
```

#### Development Environment
- **Relaxed Security**: Allows default passwords and debug settings
- **Development Features**: Permits sign-up and anonymous access
- **Debug Logging**: Recommends debug log levels

```bash
# Development validation example
./scripts/config-manager.sh validate development

# Sample output:
[INFO] Validating configuration for environment: development
[WARN] Using default development password
[WARN] Consider using debug log level in development
[INFO] Configuration validation completed successfully
```

#### Staging Environment
- **Balanced Approach**: Production-like security with development flexibility
- **Password Warnings**: Suggests stronger passwords but doesn't enforce
- **Feature Testing**: Allows testing of production features

### Validation Components

The configuration manager validates multiple aspects of your setup:

#### Environment Variables
- **Required Variables**: Checks for all mandatory environment variables
- **Type Validation**: Validates port numbers, boolean values, and formats
- **Range Checking**: Ensures ports are within valid ranges (1024-65535)

#### Service Configurations
- **Syntax Validation**: Checks YAML, INI, and TOML file syntax
- **Required Sections**: Validates presence of mandatory configuration sections
- **Cross-Reference**: Ensures configuration consistency between services

#### System Resources
- **Port Availability**: Checks if required ports are available
- **System Capacity**: Validates available memory and disk space
- **Network Connectivity**: Tests external connectivity for image downloads

#### Security Validation
- **Password Strength**: Validates password complexity and length
- **Token Format**: Checks token format (64-character hex strings)
- **File Permissions**: Validates secure file permissions for sensitive files

## Template System

### Available Templates

The configuration manager includes templates for all core services:

| Service | Template File | Configuration Type | Description |
|---------|---------------|-------------------|-------------|
| Grafana | `grafana.template` | INI | Complete Grafana configuration with security settings |
| Prometheus | `prometheus.template` | YAML | Scrape targets, alerting, and retention settings |
| Loki | `loki.template` | YAML | Advanced log aggregation with caching and retention |
| Alloy | `alloy.template` | HCL | Telemetry collection and forwarding configuration |
| Telegraf | `telegraf.template` | TOML | System metrics collection with input/output plugins |
| InfluxDB | `influxdb.template` | INI | Database configuration with performance tuning |

### Creating Templates

```bash
# Create a new service template
./scripts/config-manager.sh template grafana

# This creates templates/grafana.template with environment variable placeholders
```

### Template Structure

Templates use environment variable substitution with the `${VARIABLE_NAME}` syntax:

```ini
# Example Grafana template snippet
[server]
protocol = http
http_port = ${GRAFANA_PORT}
domain = ${GRAFANA_DOMAIN}

[security]
admin_user = ${GRAFANA_ADMIN_USER}
admin_password = ${GRAFANA_ADMIN_PASSWORD}
```

### Generating Configurations

```bash
# Generate all service configurations for development
./scripts/config-manager.sh generate development

# Generated files are placed in configs/generated/
ls configs/generated/
# grafana-development.conf
# prometheus-development.conf
# loki-development.conf
# ...
```

## Configuration Comparison

### Environment Comparison

Compare configurations between different environments to identify differences:

```bash
# Compare development and production environments
./scripts/config-manager.sh diff development production

# Sample output:
Configuration Differences:
==========================
--- .env.development    2023-12-15 10:30:00.000000000 +0000
+++ .env.production     2023-12-15 10:35:00.000000000 +0000
@@ -15,7 +15,7 @@
 GRAFANA_PORT=3000
 
 # Security credentials
-GRAFANA_ADMIN_PASSWORD=admin
+GRAFANA_ADMIN_PASSWORD=secure-production-password
 
 # Feature toggles
-GRAFANA_ALLOW_SIGN_UP=true
+GRAFANA_ALLOW_SIGN_UP=false
```

### Configuration Health Check

The health check command performs comprehensive validation of your entire configuration:

```bash
./scripts/config-manager.sh check

# Sample output:
[INFO] Checking configuration health and consistency...
[INFO] Found environment file: .env.development
[INFO] Found environment file: .env.production
[WARN] Default passwords detected in .env file
[INFO] Configuration health check passed
```

## Configuration Export and Import

### Export Configuration

Create portable configuration packages for deployment automation:

```bash
# Export production configuration
./scripts/config-manager.sh export production -o prod-config-$(date +%Y%m%d).tar.gz

# Export includes:
# - Environment files (.env.production)
# - Configuration directories (configs/)
# - Docker Compose files
# - Export manifest with metadata
```

### Export Package Contents

```
pimonitor-config-production-20231215_143022.tar.gz
├── MANIFEST.txt                    # Export metadata
├── .env.example                    # Environment template
├── .env.production                 # Production environment
├── configs/                        # Service configurations
│   ├── grafana/
│   ├── prometheus/
│   ├── loki/
│   └── ...
├── docker-compose.yml              # Core services
├── docker-compose.override.yml     # Development overrides
├── docker-compose.prod.yml         # Production overrides
└── docker-compose.optional.yml     # Optional services
```

### Import Configuration

```bash
# Import configuration package (planned feature)
./scripts/config-manager.sh import prod-config-20231215.tar.gz
```

## Advanced Usage

### Custom Template Directory

Use custom template directories for organization-specific configurations:

```bash
# Use custom template directory
./scripts/config-manager.sh generate production -t /path/to/custom/templates
```

### Verbose Output

Enable detailed logging for troubleshooting:

```bash
# Enable verbose output
./scripts/config-manager.sh validate production -v

# This enables DEBUG level logging and shows detailed validation steps
```

### Force Operations

Override confirmation prompts for automation:

```bash
# Force template creation (overwrite existing)
./scripts/config-manager.sh template grafana -f

# Force export without confirmation
./scripts/config-manager.sh export production -f -o config.tar.gz
```

## Integration with CI/CD

### Automated Validation

Integrate configuration validation into your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
name: Configuration Validation
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate Configuration
        run: |
          ./scripts/config-manager.sh validate production
          ./scripts/config-manager.sh check
      - name: Docker Resource Cleanup
        run: |
          ./scripts/docker-cleanup.sh --safe --force
```

### Environment-Specific Deployment

```bash
# Deployment script example
#!/bin/bash
set -e

ENVIRONMENT=${1:-development}

# Validate configuration before deployment
./scripts/config-manager.sh validate "$ENVIRONMENT"

# Generate configurations from templates
./scripts/config-manager.sh generate "$ENVIRONMENT"

# Deploy with environment-specific configuration
docker compose -f docker-compose.yml -f "docker-compose.${ENVIRONMENT}.yml" up -d
```

## Troubleshooting

### Common Issues

#### Template Not Found
```bash
[ERROR] No template found for service: grafana
```

**Solution**: Create the missing template:
```bash
./scripts/config-manager.sh template grafana
```

#### Validation Failures
```bash
[ERROR] Configuration validation failed with 2 errors
```

**Solution**: Run with verbose output to see detailed errors:
```bash
./scripts/config-manager.sh validate production -v
```

#### Environment File Missing
```bash
[WARN] No environment configuration found for: production
```

**Solution**: Create the environment file:
```bash
cp .env.example .env.production
# Edit .env.production with production-specific values
```

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
# Set debug log level
export LOG_LEVEL=0

# Run with verbose output
./scripts/config-manager.sh validate production -v

# Check log file for detailed information
tail -f logs/pimonitor.log
```

## Best Practices

### Environment Management

1. **Separate Environment Files**: Use `.env.development`, `.env.production`, `.env.staging`
2. **Template Consistency**: Keep templates updated with new configuration options
3. **Regular Validation**: Run validation checks before deployments
4. **Configuration Backup**: Export configurations before major changes

### Security Practices

1. **Strong Passwords**: Use the configuration manager's password validation
2. **Token Generation**: Generate secure tokens with `openssl rand -hex 32`
3. **File Permissions**: Ensure sensitive files have appropriate permissions
4. **Regular Audits**: Use the health check command regularly

### Automation Integration

1. **CI/CD Validation**: Include configuration validation in your pipeline
2. **Deployment Scripts**: Use the configuration manager in deployment automation
3. **Configuration Drift**: Regular comparison between environments
4. **Backup Automation**: Automated configuration exports
5. **Resource Cleanup**: Integrate Docker cleanup in maintenance workflows

## Configuration Manager Architecture

### Script Structure

The configuration manager is built using the PiMonitor script library system:

```bash
# Core libraries used
source "$SCRIPT_DIR/lib/common.sh"      # Logging, error handling, utilities
source "$SCRIPT_DIR/lib/validation.sh"  # Configuration validation functions
```

### Key Components

- **Argument Parsing**: Comprehensive command-line argument handling
- **Environment Loading**: Automatic environment file detection and loading
- **Validation Engine**: Multi-tier validation with environment-specific rules
- **Template Engine**: Environment variable substitution and file generation
- **Export System**: Configuration packaging with metadata
- **Error Handling**: Robust error handling with detailed reporting

### Extensibility

The configuration manager is designed for extensibility:

- **New Services**: Add new service templates easily
- **Custom Validation**: Extend validation rules for specific requirements
- **Additional Environments**: Support for custom environment types
- **Plugin Architecture**: Framework for additional configuration management features

This comprehensive configuration management system ensures reliable, secure, and maintainable PiMonitor deployments across all environments.