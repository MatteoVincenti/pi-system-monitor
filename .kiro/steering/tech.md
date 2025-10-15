---
inclusion: always
---

# PiMonitor Technical Guidelines

## Critical Constraints for AI Assistant

**NEVER Do These Actions**
- Install services on host system (everything runs in Docker containers)
- Compile or build code (configuration-only changes)
- Hardcode values in Docker Compose files (use environment variables)
- Commit `.env` files (only update `.env.example` template)
- Start services without Loki logging driver configuration

**ALWAYS Do These Actions**
- Use `docker compose` commands for all service management
- Mount configs from `./configs/` as read-only volumes
- Include Loki logging driver in all service definitions
- Restart containers after configuration changes
- Use ARM64-compatible Docker images

## Required Docker Images (ARM64)

| Service | Image | Purpose |
|---------|-------|---------|
| Telegraf | `telegraf:alpine` | System metrics collection |
| InfluxDB | `influxdb:alpine` | Time-series database |
| Prometheus | `prom/prometheus:latest` | Metrics storage |
| Grafana | `grafana/grafana-oss:latest` | Visualization dashboard |
| Loki | `grafana/loki:latest` | Log aggregation |
| Alloy | `grafana/alloy:latest` | Telemetry collection |

## Standard Commands for AI to Use

**Service Management**
```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d [service-name]

# Restart after config changes (REQUIRED)
docker compose restart [service-name]

# Stop all services
docker compose down

# Check service status
docker compose ps

# View service logs
docker compose logs [service-name] --tail 50
```

**Environment Configuration**
```bash
# Generate secure tokens (for .env.example updates)
openssl rand --hex 32

# Validate Loki driver installation
docker plugin ls | grep loki
```

## File Modification Patterns

**Adding New Services**
1. Create `docker-compose.[service].yml` for optional services
2. Add environment variables to `.env.example` (never `.env`)
3. Create `configs/[service]/` directory if needed
4. Ensure ARM64 image compatibility

**Configuration Updates**
1. Edit files in `./configs/[service]/` directory
2. Run `docker compose restart [service]` to apply changes
3. Verify with `docker compose logs [service]`

**Environment Variables**
- Naming pattern: `SERVICENAME_PORT`, `SERVICENAME_TOKEN`
- Default ports: Grafana (3000), InfluxDB (8086), Prometheus (9090), Loki (3100)
- Generate tokens: `openssl rand --hex 32`

## Network Architecture

- **Network Name**: `skynet` (bridge driver)
- **Inter-service Communication**: `http://servicename:port`
- **External Access**: Only through environment-configured ports
- **Logging**: All services use Loki driver with URL `http://loki:3100/loki/api/v1/push`