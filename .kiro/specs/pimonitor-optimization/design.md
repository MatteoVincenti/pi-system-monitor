# Design Document

## Overview

This design document outlines the comprehensive optimization of the PiMonitor observability stack to implement modern Docker and Docker Compose best practices, improve folder structure organization, enhance script functionality, remove the deprecated Homarr service, and implement robust system log monitoring following Grafana's official recommendations.

The optimization focuses on creating a maintainable, secure, and efficient monitoring infrastructure that follows industry standards while providing comprehensive observability for Raspberry Pi and Linux systems.

## Architecture

### Folder Structure Redesign

The new folder structure follows Docker Compose best practices with clear separation of concerns:

```
pimonitor/
├── .env.example                    # Environment template
├── .env                           # Runtime environment (gitignored)
├── docker-compose.yml             # Core monitoring stack
├── docker-compose.override.yml    # Development overrides
├── docker-compose.prod.yml        # Production overrides
├── docker-compose.optional.yml    # Optional services
├── configs/                       # Configuration files
│   ├── grafana/
│   │   ├── grafana.ini
│   │   ├── provisioning/
│   │   │   ├── datasources/
│   │   │   ├── dashboards/
│   │   │   └── alerting/
│   │   └── dashboards/
│   ├── loki/
│   │   └── loki.yml
│   ├── alloy/
│   │   └── config.alloy
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   ├── telegraf/
│   │   └── telegraf.conf
│   └── influxdb/
│       └── influxdb.conf
├── scripts/
│   ├── setup.sh                   # Initial setup and validation
│   ├── deploy.sh                  # Deployment management
│   ├── backup.sh                  # Data backup operations
│   ├── logs.sh                    # Log management utilities
│   └── lib/                       # Shared script libraries
│       ├── common.sh
│       ├── docker.sh
│       └── validation.sh
├── data/                          # Persistent data (gitignored)
│   ├── grafana/
│   ├── influxdb/
│   ├── prometheus/
│   └── loki/
└── docs/                          # Documentation
    ├── deployment.md
    ├── configuration.md
    └── troubleshooting.md
```

### Service Architecture

The optimized architecture implements proper service layering and dependencies:

**Data Layer:**
- InfluxDB: Time-series metrics storage
- Loki: Log aggregation and storage
- Prometheus: Metrics collection and storage

**Collection Layer:**
- Telegraf: System metrics collection
- Alloy: Unified telemetry collection (replaces Promtail)

**Visualization Layer:**
- Grafana: Dashboards and alerting

**Network Architecture:**
- Custom bridge network `monitoring-net` for service isolation
- Service discovery via Docker DNS
- Proper port exposure only where necessary

## Components and Interfaces

### Docker Compose Structure

**Core Services (docker-compose.yml):**
```yaml
services:
  influxdb:
    image: influxdb:2.7-alpine
    user: "1000:1000"
    healthcheck:
      test: ["CMD", "influx", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    
  prometheus:
    image: prom/prometheus:v2.48.0
    user: "nobody"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    
  loki:
    image: grafana/loki:2.9.0
    user: "10001"
    command: -config.file=/etc/loki/local-config.yaml
    
  alloy:
    image: grafana/alloy:v0.38.0
    user: "472"
    command:
      - run
      - /etc/alloy/config.alloy
      - --server.http.listen-addr=0.0.0.0:12345
    
  telegraf:
    image: telegraf:1.28-alpine
    user: "telegraf"
    
  grafana:
    image: grafana/grafana-oss:10.2.0
    user: "472"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_admin_password
```

### Security Implementation

**Non-Root Users:**
- All services run as non-root users with specific UIDs
- Proper file permissions for mounted volumes
- Capability dropping where applicable

**Secrets Management:**
- Docker secrets for sensitive data
- Environment file encryption support
- Token generation utilities

**Resource Limits:**
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
    reservations:
      memory: 256M
      cpus: '0.25'
```

### Enhanced Script Architecture

**Modular Design:**
- `lib/common.sh`: Shared utilities, logging, error handling
- `lib/docker.sh`: Docker-specific operations
- `lib/validation.sh`: Configuration validation

**Error Handling Pattern:**
```bash
#!/bin/bash
set -euo pipefail
trap 'handle_error $? $LINENO' ERR

source "$(dirname "$0")/lib/common.sh"

handle_error() {
    log_error "Script failed at line $2 with exit code $1"
    cleanup
    exit "$1"
}
```

**Logging Implementation:**
```bash
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}
```

## Data Models

### Environment Configuration Model

```bash
# Core Services
GRAFANA_PORT=3000
GRAFANA_ADMIN_PASSWORD_FILE=/run/secrets/grafana_admin_password
INFLUXDB_PORT=8086
INFLUXDB_ADMIN_TOKEN_FILE=/run/secrets/influxdb_admin_token
PROMETHEUS_PORT=9090
LOKI_PORT=3100
ALLOY_PORT=12345
TELEGRAF_INTERVAL=10s

# Network Configuration
MONITORING_NETWORK=monitoring-net
COMPOSE_PROJECT_NAME=pimonitor

# Storage Configuration
DATA_PATH=./data
CONFIG_PATH=./configs

# Log Configuration
LOKI_RETENTION_PERIOD=30d
LOG_LEVEL=info

# Resource Limits
GRAFANA_MEMORY_LIMIT=512m
INFLUXDB_MEMORY_LIMIT=1g
PROMETHEUS_MEMORY_LIMIT=512m
LOKI_MEMORY_LIMIT=512m
```

### Loki Configuration Model

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  retention_period: 30d
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
```

### Alloy Configuration Model

```hcl
// System logs collection
loki.source.file "system_logs" {
  targets = [
    {__path__ = "/var/log/syslog"},
    {__path__ = "/var/log/auth.log"},
    {__path__ = "/var/log/kern.log"},
  ]
  forward_to = [loki.write.default.receiver]
}

// Docker container logs
loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = []
  forward_to = [loki.write.default.receiver]
  relabel_rules = rule{
    source_labels = ["__meta_docker_container_name"]
    target_label  = "container"
  }
}

// Application logs
loki.source.file "app_logs" {
  targets = [
    {__path__ = "/app/logs/*.log", service = "pimonitor"},
  ]
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

## Error Handling

### Docker Health Checks

All services implement comprehensive health checks:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Script Error Handling

```bash
# Validation functions
validate_environment() {
    local required_vars=(
        "GRAFANA_PORT"
        "INFLUXDB_PORT"
        "PROMETHEUS_PORT"
        "LOKI_PORT"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done
}

# Docker validation
validate_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        return 1
    fi
    
    if ! docker plugin ls | grep -q loki; then
        log_error "Loki Docker plugin is not installed"
        return 1
    fi
}
```

### Service Recovery

```bash
# Automatic service recovery
recover_service() {
    local service="$1"
    log_info "Attempting to recover service: $service"
    
    docker compose restart "$service"
    
    # Wait for health check
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if docker compose ps "$service" | grep -q "healthy"; then
            log_info "Service $service recovered successfully"
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_error "Failed to recover service: $service"
    return 1
}
```

## Testing Strategy

### Configuration Validation Tests

```bash
# Test environment configuration
test_environment_config() {
    log_info "Testing environment configuration..."
    
    # Load environment
    if [[ -f .env ]]; then
        source .env
    else
        log_error ".env file not found"
        return 1
    fi
    
    # Validate required variables
    validate_environment || return 1
    
    # Test port availability
    for port in "$GRAFANA_PORT" "$INFLUXDB_PORT" "$PROMETHEUS_PORT" "$LOKI_PORT"; do
        if netstat -tuln | grep -q ":$port "; then
            log_error "Port $port is already in use"
            return 1
        fi
    done
    
    log_info "Environment configuration is valid"
}
```

### Service Integration Tests

```bash
# Test service connectivity
test_service_connectivity() {
    log_info "Testing service connectivity..."
    
    local services=("grafana" "influxdb" "prometheus" "loki")
    
    for service in "${services[@]}"; do
        if ! docker compose exec "$service" wget -q --spider "http://localhost:${service^^}_PORT/health" 2>/dev/null; then
            log_error "Service $service is not responding to health checks"
            return 1
        fi
    done
    
    log_info "All services are responding correctly"
}
```

### Log Ingestion Tests

```bash
# Test log ingestion pipeline
test_log_ingestion() {
    log_info "Testing log ingestion pipeline..."
    
    # Generate test log entry
    echo "Test log entry $(date)" | docker compose exec -T alloy logger
    
    # Wait for ingestion
    sleep 5
    
    # Query Loki for test entry
    if ! curl -s "http://localhost:$LOKI_PORT/loki/api/v1/query?query={job=\"syslog\"}" | grep -q "Test log entry"; then
        log_error "Log ingestion test failed"
        return 1
    fi
    
    log_info "Log ingestion is working correctly"
}
```

### Performance Tests

```bash
# Test resource usage
test_resource_usage() {
    log_info "Testing resource usage..."
    
    # Check memory usage
    local memory_usage
    memory_usage=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep -E "(grafana|influxdb|prometheus|loki)")
    
    log_info "Current memory usage:"
    echo "$memory_usage"
    
    # Check if any service exceeds limits
    if docker stats --no-stream --format "{{.Container}} {{.MemPerc}}" | awk '$2 > 90 {print $1}' | grep -q .; then
        log_error "Some services are using excessive memory"
        return 1
    fi
    
    log_info "Resource usage is within acceptable limits"
}
```