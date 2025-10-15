---
inclusion: always
---

# Technology Stack & Technical Constraints

## Platform Requirements
- **Docker Engine**: Required with Docker Compose v2
- **ARM64 Architecture**: All images must support ARM64 for Raspberry Pi
- **Grafana Loki Docker Driver**: MUST be installed before starting services
  ```bash
  docker plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions
  ```

## Service Stack & Versions
- **Telegraf**: `telegraf:alpine` - System metrics collection
- **InfluxDB**: `influxdb:alpine` - Time-series database
- **Prometheus**: `prom/prometheus:latest` - Metrics storage
- **Grafana**: `grafana/grafana-oss:latest` - Visualization
- **Loki**: `grafana/loki:latest` - Log aggregation
- **Alloy**: `grafana/alloy:latest` - Telemetry collection

## Configuration Patterns
- **Environment Variables**: Use `.env` file, never hardcode values
- **Config Files**: Mount from `./configs/` as read-only volumes
- **Persistent Data**: Use named Docker volumes for databases
- **Logging**: ALL services MUST use Loki driver with `loki-url: http://loki:3100/loki/api/v1/push`

## Development Constraints
- **No Compilation**: Configuration-only changes, no code building
- **Container-Only**: Never install services directly on host
- **Network**: All services use `skynet` bridge network
- **Ports**: Use environment variables for port configuration
- **Security**: Generate tokens with `openssl rand --hex 32`

## Required Commands for AI Operations
```bash
# Service lifecycle
docker compose up -d [service]
docker compose down
docker compose restart [service]

# Configuration changes (requires restart)
docker compose restart [service]

# Logs and debugging
docker compose logs [service]
docker plugin ls | grep loki

# Environment setup
cp .env.example .env
```

## File Modification Rules
- **Docker Compose**: Modify existing services, create new files for optional services
- **Environment**: Update `.env.example` template, never commit `.env`
- **Configs**: Edit files in `configs/` directory, restart affected containers
- **Scripts**: Maintain POSIX compatibility, use `set -e` for error handling