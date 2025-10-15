---
inclusion: always
---

# PiMonitor Architecture & Code Patterns

PiMonitor is a containerized observability stack for Raspberry Pi. This document defines architectural patterns and coding conventions for AI assistants working with this codebase.

## Mandatory Service Dependencies

**Startup Order (CRITICAL)**
1. InfluxDB → 2. Prometheus → 3. Loki → 4. Telegraf → 5. Alloy → 6. Grafana

**Required Docker Compose Pattern**
```yaml
services:
  service-name:
    depends_on:
      - prerequisite-service
    volumes:
      - ./configs/service-name:/config:ro
      - service_data:/data
    networks:
      - skynet
    logging:
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
    environment:
      - SERVICENAME_PORT=${SERVICENAME_PORT}
      - SERVICENAME_TOKEN=${SERVICENAME_TOKEN}

volumes:
  service_data:

networks:
  skynet:
    driver: bridge
```

## File Organization Rules

**Core vs Optional Services**
- **Core services**: Modify existing `docker-compose.yml`
- **Optional services**: Create new `docker-compose.[service].yml` files
- **Configuration**: Store in `./configs/[service]/` directory
- **Environment**: Update `.env.example` template (never commit `.env`)

**Directory Structure Pattern**
```
configs/
├── service-name/
│   ├── config.yml          # Main configuration
│   └── rules/              # Service-specific rules
data/
├── service-name/           # Persistent data (Docker volumes)
```

## Configuration Change Workflow

**Standard Process for AI Assistant**
1. Edit configuration files in `./configs/[service]/`
2. Update environment variables in `.env.example`
3. Execute: `docker compose restart [service]`
4. Validate: `docker compose logs [service] --tail 20`
5. Verify service health: `docker compose ps [service]`

## Environment Variable Conventions

**Naming Standards**
- Format: `SERVICENAME_SETTING` (uppercase, underscore-separated)
- Ports: `GRAFANA_PORT=3000`, `INFLUXDB_PORT=8086`
- Tokens: `GRAFANA_ADMIN_TOKEN`, `INFLUXDB_TOKEN`
- URLs: `LOKI_URL=http://loki:3100`

**Token Generation**
```bash
# Generate 32-character hex token
openssl rand --hex 32
```

## ARM64 Compatibility Requirements

**Image Selection Criteria**
- MUST support ARM64 architecture
- Prefer Alpine variants for smaller footprint
- Set memory limits: 512MB-1GB per service
- Use specific version tags, avoid `latest` in production

**Resource Constraints**
```yaml
deploy:
  resources:
    limits:
      memory: 1G
    reservations:
      memory: 512M
```

## Network & Security Patterns

**Inter-Service Communication**
- Network: `skynet` bridge driver
- Internal URLs: `http://service-name:port`
- External access: Only through environment-configured ports
- No direct host network access

**Data Persistence Strategy**
- **Databases**: Named Docker volumes (persistent across restarts)
- **Configuration**: Read-only mounts from `./configs/`
- **Logs**: Centralized through Loki Docker driver
- **Secrets**: Environment variables only, never hardcoded