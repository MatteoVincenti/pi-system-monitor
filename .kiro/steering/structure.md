---
inclusion: always
---

# Project Structure & Patterns

## File Organization Rules

**Root Level**: Core orchestration files only
- `docker-compose.yaml`: Main monitoring stack - modify for core service changes
- `docker-compose.*.yaml`: Optional services - create new files for additional services
- `.env`: Runtime configuration - never commit, always use `.env.example` as template

**Configuration Directory (`configs/`)**
- Mount point for all service configurations
- Files are read-only mounted into containers
- Changes require container restart to take effect
- Use service-specific subdirectories for complex configs (e.g., `prometheus/`)

**Scripts Directory (`scripts/`)**
- Executable scripts must have proper shebang (`#!/bin/bash`)
- Interactive scripts use `select` for user input
- Utility scripts in `utilities/` are non-interactive
- All scripts should handle errors gracefully

## Docker Compose Patterns

**Service Definition Rules**
- Use `depends_on` for startup ordering
- Mount configs from `./configs/` as read-only
- Use named volumes for persistent data
- All services join `skynet` network
- Include health checks where supported

**Environment Variable Conventions**
- Format: `SERVICENAME_PORT`, `SERVICENAME_TOKEN`
- Default ports: Grafana (3000), InfluxDB (8086), Prometheus (9090), Loki (3100)
- Security tokens generated with `openssl rand --hex 32`

**Logging Configuration**
- All services must use Loki Docker driver
- Format: `driver: loki`, `options: loki-url: http://loki:3100/loki/api/v1/push`

## Modification Guidelines

**Adding New Services**
1. Create separate `docker-compose.SERVICE.yaml` file
2. Add environment variables to `.env.example`
3. Create config files in `configs/SERVICE/` if needed
4. Update documentation

**Configuration Changes**
- Edit files in `configs/` directory
- Restart affected containers: `docker compose restart SERVICE`
- Test changes before committing

**Script Modifications**
- Maintain POSIX compatibility
- Use `set -e` for error handling
- Include usage documentation in comments