---
inclusion: always
---

# PiMonitor Product Guidelines

PiMonitor is a Docker-based observability stack for Raspberry Pi and Linux systems. When working with this codebase, follow these product conventions and architectural patterns.

## Architecture Principles

- **Container-First**: All services run as Docker containers with no local compilation
- **Configuration-Driven**: Services configured via mounted files from `configs/` directory
- **Modular Deployment**: Core stack + optional services via separate compose files
- **Single Network**: All services communicate via `skynet` bridge network
- **Persistent Storage**: Named volumes for database persistence, config files mounted read-only

## Service Dependencies

**Core Stack Order** (respect startup dependencies):
1. InfluxDB (data storage)
2. Prometheus (metrics collection)
3. Loki (log aggregation)
4. Telegraf (system metrics)
5. Alloy (telemetry collection)
6. Grafana (visualization)

**Optional Services**: Independent of core stack, can be deployed separately

## Configuration Patterns

- **Environment Variables**: Centralized in `.env` file, use `SERVICENAME_PORT` pattern
- **Security**: Generate tokens with `openssl rand --hex 32`
- **Logging**: All services must use Loki Docker driver for centralized logging
- **Health Checks**: Include health check endpoints where available
- **Resource Limits**: Set appropriate memory/CPU limits for Raspberry Pi constraints

## Development Guidelines

- **No Code Changes**: Modify configurations, not service code
- **Version Pinning**: Use specific image tags, avoid `latest` in production
- **ARM64 Support**: Ensure all images support ARM64 architecture
- **Graceful Shutdown**: Services must handle SIGTERM properly
- **Data Retention**: Configure appropriate retention policies for time-series data

## User Experience Patterns

- **Interactive Scripts**: Use `./scripts/start.sh` for guided service selection
- **Consistent Ports**: Default ports configurable via environment variables
- **Pre-configured Dashboards**: Include ready-to-use Grafana dashboards
- **Documentation**: Maintain comprehensive README with setup instructions