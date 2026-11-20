# PiMonitor Configuration Reference

This comprehensive guide covers all configuration options available in PiMonitor, from basic environment variables to advanced service configurations.

## Table of Contents

1. [Environment Configuration](#environment-configuration)
2. [Service Configurations](#service-configurations)
3. [Security Configuration](#security-configuration)
4. [Performance Tuning](#performance-tuning)
5. [Advanced Configuration](#advanced-configuration)
6. [Configuration Management](#configuration-management)

## Environment Configuration

### Core Environment Variables

#### Project Settings
```bash
# Project identification
COMPOSE_PROJECT_NAME=pimonitor          # Docker Compose project name
ENVIRONMENT=production                  # Deployment environment (development|production|staging)
INCLUDE_OPTIONAL=false                  # Include optional services (portainer, watchtower)

# Deployment settings
DEPLOY_TIMEOUT=300                      # Deployment timeout in seconds
HEALTH_CHECK_TIMEOUT=120               # Health check timeout in seconds
RESTART_POLICY=unless-stopped          # Docker restart policy
```

#### Network Configuration
```bash
# Service ports
GRAFANA_PORT=3000                      # Grafana web interface
INFLUXDB_PORT=8086                     # InfluxDB API
PROMETHEUS_PORT=9090                   # Prometheus web interface
LOKI_PORT=3100                         # Loki API
ALLOY_PORT=12345                       # Alloy web interface
TELEGRAF_PORT=8125                     # Telegraf metrics endpoint

# Optional service ports
PORTAINER_HTTP_PORT=8000               # Portainer HTTP
PORTAINER_HTTPS_PORT=9443              # Portainer HTTPS

# Network settings
MONITORING_NETWORK=pimonitor_monitoring # Docker network name
ENABLE_IPV6=false                      # Enable IPv6 support
```

### Security Configuration

#### Authentication
```bash
# Grafana authentication
GRAFANA_ADMIN_USER=admin               # Admin username
GRAFANA_ADMIN_PASSWORD=secure_password # Admin password (change this!)
GRAFANA_ADMIN_PASSWORD_FILE=/run/secrets/grafana_admin_password

# InfluxDB authentication
INFLUXDB_ADMIN_USER=admin              # Admin username
INFLUXDB_ADMIN_PASSWORD=secure_password # Admin password (change this!)
INFLUXDB_ADMIN_TOKEN=secure_token      # Admin token (change this!)
INFLUXDB_ADMIN_TOKEN_FILE=/run/secrets/influxdb_admin_token
```

#### Security Settings
```bash
# HTTPS configuration
ENABLE_HTTPS=false                     # Enable HTTPS
SSL_CERT_PATH=./certs/server.crt      # SSL certificate path
SSL_KEY_PATH=./certs/server.key       # SSL private key path
FORCE_HTTPS_REDIRECT=false             # Force HTTPS redirect

# Session security
SESSION_TIMEOUT=24h                    # Session timeout
COOKIE_SECURE=false                    # Secure cookie flag
COOKIE_SAMESITE=lax                    # SameSite cookie policy
```

### Resource Configuration

#### Memory Limits
```bash
# Service memory limits (adjust based on your system)
GRAFANA_MEMORY_LIMIT=512m              # Grafana memory limit
GRAFANA_MEMORY_RESERVATION=256m        # Grafana memory reservation
INFLUXDB_MEMORY_LIMIT=1g               # InfluxDB memory limit
INFLUXDB_MEMORY_RESERVATION=512m       # InfluxDB memory reservation
PROMETHEUS_MEMORY_LIMIT=512m           # Prometheus memory limit
PROMETHEUS_MEMORY_RESERVATION=256m     # Prometheus memory reservation
LOKI_MEMORY_LIMIT=512m                 # Loki memory limit
LOKI_MEMORY_RESERVATION=256m           # Loki memory reservation
ALLOY_MEMORY_LIMIT=256m                # Alloy memory limit
ALLOY_MEMORY_RESERVATION=128m          # Alloy memory reservation
TELEGRAF_MEMORY_LIMIT=256m             # Telegraf memory limit
TELEGRAF_MEMORY_RESERVATION=128m       # Telegraf memory reservation
```

#### CPU Limits
```bash
# Service CPU limits
GRAFANA_CPU_LIMIT=0.5                  # Grafana CPU limit (cores)
GRAFANA_CPU_RESERVATION=0.25           # Grafana CPU reservation
INFLUXDB_CPU_LIMIT=0.5                 # InfluxDB CPU limit
INFLUXDB_CPU_RESERVATION=0.25          # InfluxDB CPU reservation
PROMETHEUS_CPU_LIMIT=0.5               # Prometheus CPU limit
PROMETHEUS_CPU_RESERVATION=0.25        # Prometheus CPU reservation
LOKI_CPU_LIMIT=0.5                     # Loki CPU limit
LOKI_CPU_RESERVATION=0.25              # Loki CPU reservation
ALLOY_CPU_LIMIT=0.25                   # Alloy CPU limit
ALLOY_CPU_RESERVATION=0.1              # Alloy CPU reservation
TELEGRAF_CPU_LIMIT=0.25                # Telegraf CPU limit
TELEGRAF_CPU_RESERVATION=0.1           # Telegraf CPU reservation
```

## Service Configurations

### Grafana Configuration

PiMonitor includes a comprehensive Grafana configuration (`configs/grafana/grafana.ini`) optimized for security and performance on Raspberry Pi systems.

#### Server Configuration
```bash
# Basic server settings
GRAFANA_DOMAIN=localhost               # Server domain
GRAFANA_ROOT_URL=http://localhost:3000 # Root URL
GRAFANA_SERVE_FROM_SUB_PATH=false     # Serve from sub-path
GRAFANA_ENABLE_GZIP=true              # Enable gzip compression
GRAFANA_ROUTER_LOGGING=false          # Disable router logging for performance
```

#### Authentication & Security
```bash
# User management
GRAFANA_ALLOW_SIGN_UP=false           # Disable user registration (security)
GRAFANA_ALLOW_ORG_CREATE=false       # Disable organization creation
GRAFANA_AUTO_ASSIGN_ORG=true         # Auto-assign to organization
GRAFANA_AUTO_ASSIGN_ORG_ROLE=Viewer  # Default role for new users
GRAFANA_VIEWERS_CAN_EDIT=false       # Restrict viewer permissions
GRAFANA_EDITORS_CAN_ADMIN=false      # Restrict editor permissions

# Anonymous access (disabled by default for security)
GRAFANA_ANONYMOUS_ENABLED=false       # Enable anonymous access
GRAFANA_ANONYMOUS_ORG_NAME=Main Org.  # Anonymous organization
GRAFANA_ANONYMOUS_ORG_ROLE=Viewer     # Anonymous role

# Session security
GRAFANA_LOGIN_REMEMBER_DAYS=7         # Remember login duration
GRAFANA_COOKIE_SECURE=false           # Secure cookies (enable for HTTPS)
GRAFANA_COOKIE_SAMESITE=lax           # SameSite policy
GRAFANA_USER_INVITE_MAX_LIFETIME=24h  # User invite expiration
```

#### Security Headers & Protection
```bash
# Security hardening
GRAFANA_DISABLE_GRAVATAR=true         # Disable Gravatar for privacy
GRAFANA_DISABLE_BRUTE_FORCE_LOGIN_PROTECTION=false # Enable brute force protection
GRAFANA_ALLOW_EMBEDDING=false         # Disable iframe embedding
GRAFANA_CONTENT_TYPE_PROTECTION=true  # Enable content type protection
GRAFANA_X_CONTENT_TYPE_OPTIONS=true   # X-Content-Type-Options header
GRAFANA_X_XSS_PROTECTION=true         # XSS protection header

# HTTPS settings (for production with SSL)
GRAFANA_STRICT_TRANSPORT_SECURITY=false # Enable HSTS
GRAFANA_STRICT_TRANSPORT_SECURITY_MAX_AGE=86400 # HSTS max age
GRAFANA_STRICT_TRANSPORT_SECURITY_PRELOAD=false # HSTS preload
GRAFANA_STRICT_TRANSPORT_SECURITY_SUBDOMAINS=false # HSTS subdomains
```

#### Dashboard & Data Management
```bash
# Dashboard settings
GRAFANA_VERSIONS_TO_KEEP=20           # Dashboard version history
GRAFANA_MIN_REFRESH_INTERVAL=5s       # Minimum dashboard refresh interval
GRAFANA_DEFAULT_HOME_DASHBOARD_PATH=  # Custom home dashboard

# Data source settings
GRAFANA_DATA_SOURCE_PROXY_WHITELIST=  # Allowed proxy destinations
```

#### Logging Configuration
```bash
# Logging settings
GRAFANA_LOG_MODE=console file         # Log to console and file
GRAFANA_LOG_LEVEL=info                # Log level (debug|info|warn|error)
GRAFANA_LOG_ROTATE=true               # Enable log rotation
GRAFANA_LOG_MAX_LINES=1000000         # Max lines per log file
GRAFANA_LOG_MAX_SIZE_SHIFT=28         # Max log file size (256MB)
GRAFANA_LOG_DAILY_ROTATE=true         # Daily log rotation
GRAFANA_LOG_MAX_DAYS=7                # Keep logs for 7 days
```

#### Alerting Configuration
```bash
# Unified alerting (modern alerting system)
GRAFANA_UNIFIED_ALERTING_ENABLED=true # Enable unified alerting
GRAFANA_EXECUTE_ALERTS=true           # Execute alert rules
GRAFANA_EVALUATION_TIMEOUT=30s        # Alert evaluation timeout
GRAFANA_MAX_ATTEMPTS=1                # Max alert attempts
GRAFANA_MIN_INTERVAL=10s              # Minimum alert interval

# Legacy alerting (deprecated but included for compatibility)
GRAFANA_ALERTING_ENABLED=true         # Enable legacy alerting
GRAFANA_ALERTING_EXECUTE_ALERTS=true  # Execute legacy alerts
GRAFANA_ALERTING_ERROR_OR_TIMEOUT=alerting # Error handling
GRAFANA_ALERTING_NODATA_OR_NULLVALUES=no_data # Null value handling
GRAFANA_ALERTING_CONCURRENT_RENDER_LIMIT=5 # Concurrent render limit
```

#### Feature Toggles & Plugins
```bash
# Feature toggles (enable experimental features)
GRAFANA_FEATURE_TOGGLES=alertingSimplifiedRouting # Simplified alert routing

# Plugin management
GRAFANA_INSTALL_PLUGINS=              # Comma-separated plugin list
GRAFANA_ENABLE_ALPHA=false            # Disable alpha plugins for stability
GRAFANA_ALLOW_LOADING_UNSIGNED_PLUGINS= # Allow unsigned plugins (security risk)
GRAFANA_MARKETPLACE_URL=https://grafana.com/grafana/plugins/ # Plugin marketplace
```

#### Performance & Monitoring
```bash
# Internal metrics
GRAFANA_METRICS_ENABLED=true          # Enable internal metrics
GRAFANA_METRICS_INTERVAL_SECONDS=10   # Metrics collection interval
GRAFANA_DISABLE_TOTAL_STATS=false     # Enable total stats

# Explore feature
GRAFANA_EXPLORE_ENABLED=true          # Enable Explore tab

# Live features
GRAFANA_LIVE_MAX_CONNECTIONS=100      # Max WebSocket connections
GRAFANA_LIVE_ALLOWED_ORIGINS=         # Allowed origins for WebSocket

# Panels
GRAFANA_PANELS_DISABLE_SANITIZE_HTML=false # HTML sanitization in panels
```

#### External Integrations
```bash
# Analytics (disabled for privacy)
GRAFANA_REPORTING_ENABLED=false       # Disable usage reporting
GRAFANA_CHECK_FOR_UPDATES=false       # Disable update checks
GRAFANA_GOOGLE_ANALYTICS_UA_ID=       # Google Analytics ID
GRAFANA_GOOGLE_TAG_MANAGER_ID=        # Google Tag Manager ID

# External image storage (for sharing)
GRAFANA_EXTERNAL_IMAGE_STORAGE_PROVIDER= # Storage provider (s3|gcs|azure_blob|webdav|local)

# Snapshots
GRAFANA_SNAPSHOTS_EXTERNAL_ENABLED=false # Disable external snapshots
GRAFANA_SNAPSHOTS_PUBLIC_MODE=false   # Disable public snapshots
GRAFANA_SNAPSHOTS_REMOVE_EXPIRED=true # Auto-remove expired snapshots
```

#### Authentication Providers
```bash
# OAuth providers (disabled by default)
GRAFANA_AUTH_GITHUB_ENABLED=false     # GitHub OAuth
GRAFANA_AUTH_GOOGLE_ENABLED=false     # Google OAuth
GRAFANA_AUTH_GENERIC_OAUTH_ENABLED=false # Generic OAuth

# LDAP authentication
GRAFANA_AUTH_LDAP_ENABLED=false       # LDAP authentication
GRAFANA_AUTH_LDAP_CONFIG_FILE=/etc/grafana/ldap.toml # LDAP config file

# Basic authentication
GRAFANA_AUTH_BASIC_ENABLED=true       # Enable basic auth

# Proxy authentication
GRAFANA_AUTH_PROXY_ENABLED=false      # Proxy authentication
```

#### SMTP & Email Configuration
```bash
# Email settings (for notifications)
GRAFANA_SMTP_ENABLED=false            # Enable SMTP
GRAFANA_SMTP_HOST=localhost:587       # SMTP server
GRAFANA_SMTP_USER=                    # SMTP username
GRAFANA_SMTP_PASSWORD=                # SMTP password
GRAFANA_SMTP_FROM_ADDRESS=admin@grafana.localhost # From address
GRAFANA_SMTP_FROM_NAME=Grafana        # From name
GRAFANA_SMTP_SKIP_VERIFY=false        # Skip SSL verification

# Email templates
GRAFANA_EMAILS_WELCOME_EMAIL_ON_SIGN_UP=false # Welcome email
GRAFANA_EMAILS_TEMPLATES_PATTERN=emails/*.html # Email templates
```

### InfluxDB Configuration

#### Database Settings
```bash
# Basic configuration
INFLUXDB_HOST=influxdb                # Service hostname
INFLUXDB_INIT_MODE=setup              # Initialization mode
INFLUXDB_INIT_USERNAME=admin          # Initial admin username
INFLUXDB_INIT_PASSWORD=admin_password # Initial admin password
INFLUXDB_INIT_ORG=pimonitor          # Initial organization
INFLUXDB_INIT_BUCKET=telegraf        # Initial bucket
INFLUXDB_INIT_RETENTION=30d          # Data retention period
INFLUXDB_INIT_ADMIN_TOKEN=admin_token # Initial admin token
```

#### Performance Settings
```bash
# Storage configuration
INFLUXDB_BOLT_PATH=/var/lib/influxdb2/influxd.bolt # Bolt database path
INFLUXDB_ENGINE_PATH=/var/lib/influxdb2/engine     # Engine path
INFLUXDB_REPORTING_DISABLED=true                   # Disable telemetry

# Query settings
INFLUXDB_QUERY_CONCURRENCY=10         # Query concurrency
INFLUXDB_QUERY_QUEUE_SIZE=10          # Query queue size
INFLUXDB_QUERY_MEMORY_BYTES=0         # Query memory limit (0 = unlimited)
```

### Prometheus Configuration

#### Basic Settings
```bash
# Server configuration
PROMETHEUS_HOST=prometheus            # Service hostname
PROMETHEUS_RETENTION_TIME=30d         # Data retention time
PROMETHEUS_RETENTION_SIZE=10GB        # Data retention size
PROMETHEUS_SCRAPE_INTERVAL=15s        # Default scrape interval
PROMETHEUS_EVALUATION_INTERVAL=15s    # Rule evaluation interval
```

#### Storage Settings
```bash
# TSDB configuration
PROMETHEUS_STORAGE_TSDB_PATH=/prometheus # TSDB storage path
PROMETHEUS_STORAGE_TSDB_RETENTION_TIME=30d # TSDB retention time
PROMETHEUS_STORAGE_TSDB_RETENTION_SIZE=10GB # TSDB retention size
```

#### Query Settings
```bash
# Query configuration
PROMETHEUS_QUERY_TIMEOUT=2m           # Query timeout
PROMETHEUS_QUERY_MAX_CONCURRENCY=20   # Max concurrent queries
PROMETHEUS_QUERY_MAX_SAMPLES=50000000 # Max samples per query
```

#### Web Settings
```bash
# Web interface configuration
PROMETHEUS_WEB_ENABLE_LIFECYCLE=true  # Enable lifecycle API
PROMETHEUS_WEB_ENABLE_ADMIN_API=false # Enable admin API
PROMETHEUS_WEB_EXTERNAL_URL=http://localhost:9090 # External URL
```

### Loki Configuration

#### Basic Settings
```bash
# Server configuration
LOKI_HOST=loki                        # Service hostname
LOKI_HTTP_PORT=3100                   # HTTP port
LOKI_GRPC_PORT=9096                   # gRPC port

# Storage configuration
LOKI_STORAGE_TYPE=filesystem          # Storage type
LOKI_STORAGE_PATH=/loki               # Storage path
LOKI_RETENTION_PERIOD=30d             # Log retention period
```

#### Performance Settings
```bash
# Ingestion limits
LOKI_INGESTION_RATE_MB=32             # Ingestion rate limit (MB/s)
LOKI_INGESTION_BURST_SIZE_MB=64       # Ingestion burst size (MB)
LOKI_MAX_STREAMS_PER_USER=10000       # Max streams per user
LOKI_MAX_LINE_SIZE=256000             # Max line size (bytes)

# Query limits
LOKI_QUERY_TIMEOUT=1m                 # Query timeout
LOKI_MAX_QUERY_PARALLELISM=32         # Max query parallelism
LOKI_MAX_QUERY_SERIES=500             # Max query series
```

### Alloy Configuration

#### Basic Settings
```bash
# Server configuration
ALLOY_HOST=alloy                      # Service hostname
ALLOY_HTTP_PORT=12345                 # HTTP port
ALLOY_STORAGE_PATH=/var/lib/alloy     # Storage path

# Log collection settings
ALLOY_LOG_LEVEL=info                  # Log level
ALLOY_ENABLE_FEATURES=                # Enabled features

# Target endpoints
ALLOY_LOKI_ENDPOINT=http://loki:3100/loki/api/v1/push # Loki endpoint
ALLOY_PROMETHEUS_ENDPOINT=http://prometheus:9090/api/v1/write # Prometheus endpoint
```

### Telegraf Configuration

#### Basic Settings
```bash
# Agent configuration
TELEGRAF_HOST=telegraf                # Service hostname
TELEGRAF_HOSTNAME=                    # Override hostname (empty = auto)
TELEGRAF_INTERVAL=10s                 # Collection interval
TELEGRAF_ROUND_INTERVAL=true          # Round collection interval
TELEGRAF_METRIC_BATCH_SIZE=1000       # Metric batch size
TELEGRAF_METRIC_BUFFER_LIMIT=10000    # Metric buffer limit
```

#### Collection Settings
```bash
# Timing configuration
TELEGRAF_COLLECTION_JITTER=0s         # Collection jitter
TELEGRAF_FLUSH_INTERVAL=10s           # Flush interval
TELEGRAF_FLUSH_JITTER=0s              # Flush jitter

# Precision and logging
TELEGRAF_PRECISION=                   # Timestamp precision
TELEGRAF_LOGFILE=                     # Log file path
TELEGRAF_LOGFILE_ROTATION_INTERVAL=0d # Log rotation interval
TELEGRAF_LOGFILE_ROTATION_MAX_SIZE=0MB # Max log file size
TELEGRAF_LOGFILE_ROTATION_MAX_ARCHIVES=5 # Max log archives
```

#### Debug Settings
```bash
# Debug configuration
TELEGRAF_DEBUG=false                  # Enable debug mode
TELEGRAF_QUIET=false                  # Quiet mode
```

## Logging Configuration

### Global Log Settings
```bash
# Log configuration
LOG_LEVEL=info                        # Global log level (debug|info|warn|error|fatal)
LOG_FORMAT=json                       # Log format (json|logfmt)
LOG_RETENTION_DAYS=30                 # Log retention period
LOG_MAX_SIZE=100m                     # Max log file size
LOG_MAX_FILES=5                       # Max log files to keep
```

### Service-Specific Log Levels
```bash
# Individual service log levels
GRAFANA_LOG_LEVEL=info                # Grafana log level
INFLUXDB_LOG_LEVEL=info               # InfluxDB log level
PROMETHEUS_LOG_LEVEL=info             # Prometheus log level
LOKI_LOG_LEVEL=info                   # Loki log level
ALLOY_LOG_LEVEL=info                  # Alloy log level
TELEGRAF_LOG_LEVEL=info               # Telegraf log level
```

### Loki Docker Driver Settings
```bash
# Docker logging configuration
LOKI_DRIVER_URL=http://loki:3100/loki/api/v1/push # Loki driver URL
LOKI_DRIVER_MAX_RETRIES=3             # Max retries for log delivery
LOKI_DRIVER_TIMEOUT=10s               # Timeout for log delivery
```

## Backup and Maintenance Configuration

### Backup Settings
```bash
# Backup configuration
BACKUP_ENABLED=true                   # Enable automated backups
BACKUP_SCHEDULE=0 2 * * *             # Backup schedule (cron format)
BACKUP_RETENTION_DAYS=30              # Backup retention period
BACKUP_COMPRESSION=true               # Enable backup compression
BACKUP_ENCRYPTION=false               # Enable backup encryption
```

### Maintenance Settings
```bash
# Cleanup configuration
AUTO_CLEANUP_ENABLED=true             # Enable automatic cleanup
CLEANUP_SCHEDULE=0 3 * * 0            # Cleanup schedule (weekly)
CLEANUP_UNUSED_IMAGES=true            # Clean unused Docker images
CLEANUP_UNUSED_VOLUMES=false          # Clean unused Docker volumes
CLEANUP_UNUSED_NETWORKS=true          # Clean unused Docker networks

# Update configuration
AUTO_UPDATE_ENABLED=false             # Enable automatic updates
UPDATE_SCHEDULE=0 4 * * 0             # Update schedule (weekly)
UPDATE_NOTIFICATION_ENABLED=true      # Enable update notifications
```

## Development and Debugging Configuration

### Development Settings
```bash
# Development mode (only for ENVIRONMENT=development)
DEV_ENABLE_DEBUG_LOGGING=true         # Enable debug logging
DEV_ENABLE_PROFILING=false            # Enable profiling
DEV_ENABLE_METRICS_DEBUG=false        # Enable metrics debugging
DEV_DISABLE_AUTH=false                # Disable authentication
DEV_MOCK_DATA_ENABLED=false           # Enable mock data generation
```

### Debug Ports
```bash
# Debug ports (only exposed in development)
GRAFANA_DEBUG_PORT=2345               # Grafana debug port
PROMETHEUS_DEBUG_PORT=2346            # Prometheus debug port
LOKI_DEBUG_PORT=2347                  # Loki debug port
```

### Testing Settings
```bash
# Testing configuration
TEST_MODE=false                       # Enable test mode
TEST_DATA_ENABLED=false               # Enable test data
TEST_SKIP_MIGRATIONS=false            # Skip database migrations
```

## Advanced Configuration

### Time Zone and Locale Settings
```bash
# Internationalization
TZ=UTC                                # System timezone
GRAFANA_DEFAULT_TIMEZONE=browser      # Grafana default timezone
INFLUXDB_TZ=UTC                       # InfluxDB timezone
LANG=en_US.UTF-8                      # System language
LC_ALL=en_US.UTF-8                    # Locale settings
```

### Custom Configuration Paths
```bash
# Custom paths
CUSTOM_CONFIG_PATH=./configs/custom   # Custom configuration directory
CUSTOM_DASHBOARDS_PATH=./configs/grafana/dashboards/custom # Custom dashboards
CUSTOM_ALERTS_PATH=./configs/grafana/provisioning/alerting/custom # Custom alerts
```

### External Integrations
```bash
# Notification settings
SLACK_WEBHOOK_URL=                    # Slack webhook URL
DISCORD_WEBHOOK_URL=                  # Discord webhook URL
EMAIL_SMTP_HOST=                      # SMTP server host
EMAIL_SMTP_PORT=587                   # SMTP server port
EMAIL_SMTP_USER=                      # SMTP username
EMAIL_SMTP_PASSWORD=                  # SMTP password
EMAIL_FROM_ADDRESS=                   # From email address
EMAIL_FROM_NAME=PiMonitor             # From name
```

## Configuration Management

### Environment-Specific Files

#### Development Configuration (.env.development)
- Relaxed security settings
- Debug logging enabled
- Anonymous access allowed
- Shorter retention periods
- Higher resource limits

#### Production Configuration (.env.production)
- Strict security settings
- Optimized performance
- No anonymous access
- Longer retention periods
- Optimized resource limits

#### Staging Configuration (.env.staging)
- Production-like settings
- Testing-friendly configurations
- Balanced resource allocation
- Medium retention periods

### Configuration Validation

#### Validation Commands
```bash
# Validate specific environment
./scripts/validate-config.sh production

# Validate all environments
./scripts/validate-config.sh all

# Strict validation (fail on warnings)
./scripts/validate-config.sh production --strict

# Generate validation report
./scripts/validate-config.sh all --report validation-report.html
```

#### Configuration Management Commands
```bash
# Generate configuration from templates
./scripts/config-manager.sh generate production

# Compare configurations
./scripts/config-manager.sh diff development production

# Export configuration
./scripts/config-manager.sh export production -o prod-config.tar.gz

# Check configuration health
./scripts/config-manager.sh check
```

### Configuration Templates

#### Creating Templates
```bash
# Create service template
./scripts/config-manager.sh template grafana

# Create custom template
./scripts/config-manager.sh template custom-service
```

#### Template Variables
Templates support environment variable substitution:
- `${VARIABLE_NAME}` - Required variable
- `${VARIABLE_NAME:-default}` - Variable with default value
- `${VARIABLE_NAME:+value}` - Conditional value

### Configuration Best Practices

#### Security
1. **Change all default passwords** before deployment
2. **Use strong passwords** (12+ characters, mixed case, numbers, symbols)
3. **Generate secure tokens** using `./scripts/generate-secrets.sh`
4. **Set proper file permissions** (600 for .env, 700 for secrets/)
5. **Enable HTTPS** for external access
6. **Disable unnecessary features** in production

#### Performance
1. **Adjust memory limits** based on available system resources
2. **Optimize retention periods** based on storage capacity
3. **Tune scrape intervals** based on monitoring needs
4. **Use SSD storage** for better I/O performance
5. **Monitor resource usage** regularly

#### Maintenance
1. **Enable automated backups** for production
2. **Set up log rotation** to prevent disk space issues
3. **Configure cleanup schedules** to remove unused resources
4. **Monitor configuration drift** using validation tools
5. **Document custom configurations** for team knowledge

## Troubleshooting Configuration Issues

### Common Configuration Problems

#### Invalid Environment Variables
```bash
# Check for syntax errors
./scripts/validate-config.sh --check-only

# Fix common issues automatically
./scripts/validate-config.sh --fix
```

#### Port Conflicts
```bash
# Check port availability
./scripts/validate-config.sh production

# Change conflicting ports
echo "GRAFANA_PORT=3001" >> .env
```

#### Resource Constraints
```bash
# Check system resources
free -h
df -h

# Adjust resource limits
export GRAFANA_MEMORY_LIMIT=256m
export INFLUXDB_MEMORY_LIMIT=512m
```

#### Permission Issues
```bash
# Fix file permissions
chmod 600 .env
chmod 700 secrets/
chmod 600 secrets/*.txt

# Verify permissions
ls -la .env secrets/
```

### Configuration Debugging

#### Enable Debug Logging
```bash
# Temporary debug mode
export LOG_LEVEL=debug
./scripts/deploy.sh restart

# Permanent debug mode
echo "LOG_LEVEL=debug" >> .env
```

#### Configuration Validation
```bash
# Comprehensive validation
./scripts/validate-config.sh all --verbose

# Generate detailed report
./scripts/validate-config.sh all --report debug-report.html
```

#### Service Configuration Testing
```bash
# Test individual service configs
docker compose config grafana
docker compose config prometheus

# Validate Docker Compose syntax
docker compose config --quiet
```