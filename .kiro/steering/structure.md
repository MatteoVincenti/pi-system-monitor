---
inclusion: always
---

# File Structure & Modification Patterns

## Directory Organization

**Root Level Files**
- `docker-compose.yml`: Main monitoring stack (modify for core services)
- `docker-compose.*.yml`: Optional services (create new files)
- `.env.example`: Template for environment variables (always update this)
- `.env`: Runtime config (NEVER commit, copy from .env.example)

**Configuration Directory (`configs/`)**
- Service-specific subdirectories (e.g., `configs/prometheus/`, `configs/grafana/`)
- Files mounted read-only into containers
- Changes require container restart to take effect

**Scripts Directory (`scripts/`)**
- Must include shebang: `#!/bin/bash`
- Use `set -e` for error handling
- Interactive scripts use `select` for user input

## Docker Compose File Patterns

**Required Service Configuration**
```yaml
services:
  servicename:
    depends_on: [prerequisite-services]
    volumes:
      - ./configs/servicename:/config:ro
      - servicename_data:/data
    networks:
      - skynet
    logging:
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
```

**Volume and Network Declarations**
```yaml
volumes:
  servicename_data:

networks:
  skynet:
    driver: bridge
```

## File Modification Workflow

**Adding New Services**
1. Create `docker-compose.SERVICE.yml` file
2. Add environment variables to `.env.example`
3. Create `configs/SERVICE/` directory if needed
4. Ensure ARM64 image compatibility

**Configuration Updates**
1. Edit files in `configs/SERVICE/` directory
2. Run: `docker compose restart SERVICE`
3. Verify: `docker compose logs SERVICE`

**Environment Variable Updates**
1. Update `.env.example` template
2. User must copy to `.env` for local use
3. Follow naming: `SERVICENAME_PORT`, `SERVICENAME_TOKEN`