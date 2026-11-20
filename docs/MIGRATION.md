# Migration Guide

This document provides guidance for migrating from previous versions of PiMonitor and handling service changes.

## Homarr Service Removal

### Background
The Homarr dashboard service has been removed from PiMonitor to streamline the stack and focus on core monitoring functionality. This change improves resource efficiency and reduces complexity.

### Migration Steps

#### 1. Backup Homarr Configuration (if applicable)
If you were using Homarr, backup any custom configurations:
```bash
# Backup Homarr data (if it exists)
docker cp homarr:/app/data ./homarr-backup/ 2>/dev/null || echo "No Homarr container found"
```

#### 2. Clean Up Homarr Resources
Run the cleanup verification script to check for and remove any remaining Homarr components:
```bash
./scripts/cleanup-homarr.sh
```

This script will:
- Check for Homarr containers, volumes, networks, and images
- Identify Homarr configuration files and data directories
- Provide removal commands for any found resources
- Verify complete cleanup of the Homarr service

The script is safe to run multiple times and will only report what it finds without automatically removing resources.

#### 3. Alternative Dashboard Solutions
Consider these alternatives for dashboard functionality:

**Option 1: Use Grafana Dashboards**
- Grafana provides comprehensive dashboarding capabilities
- Pre-configured dashboards for system monitoring
- Custom dashboard creation for application monitoring

**Option 2: External Dashboard Services**
- **Homer**: Lightweight static dashboard
- **Heimdall**: Application dashboard with service discovery
- **Organizr**: Multi-service dashboard with authentication

**Option 3: Reverse Proxy Solutions**
- **Traefik**: With dashboard and service discovery
- **Nginx Proxy Manager**: Web-based proxy management
- **Caddy**: Automatic HTTPS with admin interface

### Recommended Setup

For users who need a service dashboard, we recommend using Grafana's native dashboarding capabilities:

1. **System Overview Dashboard**: Monitor system health and performance
2. **Service Status Dashboard**: Track Docker container health
3. **Log Analysis Dashboard**: View and search application logs
4. **Custom Dashboards**: Create specific monitoring views

### Configuration Changes

#### Environment Variables Removed
The following Homarr-related environment variables are no longer needed:
- `HOMARR_PORT`
- `HOMARR_CONFIG_PATH`
- `HOMARR_DATA_PATH`

#### Docker Compose Changes
- `docker-compose.homarr.yaml` file removed
- Homarr service definition removed from main compose file
- Homarr volumes and networks cleaned up

### Cleanup Verification Script

The `scripts/cleanup-homarr.sh` script provides comprehensive verification that all Homarr components have been removed:

**What it checks:**
- Docker containers with "homarr" in the name
- Docker volumes with "homarr" in the name  
- Docker networks with "homarr" in the name
- Docker images containing "homarr"
- Configuration files in `./configs/` directory
- Data directories in `./data/` directory
- Docker Compose files with "homarr" in the filename

**Script features:**
- Color-coded output for easy reading
- Non-destructive verification (reports findings without removing)
- Provides exact commands to remove found resources
- Safe to run multiple times
- Confirms successful Homarr removal

### Benefits of Removal

1. **Reduced Resource Usage**: Lower memory and CPU consumption
2. **Simplified Architecture**: Fewer services to manage and monitor
3. **Improved Security**: Reduced attack surface
4. **Better Focus**: Concentrated on core monitoring functionality
5. **Easier Maintenance**: Fewer components to update and troubleshoot

## Version 2.0 Migration

### Breaking Changes
- Homarr service completely removed
- New modular Docker Compose structure
- Updated folder organization
- Enhanced security configurations

### Migration Checklist
- [ ] Backup existing data and configurations
- [ ] Run Homarr cleanup script
- [ ] Update environment variables
- [ ] Deploy new stack architecture
- [ ] Verify all services are healthy
- [ ] Configure alternative dashboard solution (if needed)

### Rollback Plan
If you need to rollback to a previous version:

1. Stop the new stack:
   ```bash
   docker compose down
   ```

2. Restore from backup:
   ```bash
   # Restore your backed up configurations
   cp -r backup/* ./
   ```

3. Use the previous version's Docker Compose files

## Support

If you encounter issues during migration:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review service logs: `docker compose logs service-name`
3. Verify configuration: `docker compose config`
4. Run cleanup scripts if needed

For additional support, please open an issue in the project repository with:
- Migration step where the issue occurred
- Error messages or logs
- System information (OS, Docker version, hardware)