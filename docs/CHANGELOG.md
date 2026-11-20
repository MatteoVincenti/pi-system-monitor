# PiMonitor Changelog

## Version 2.0.0 - Docker Optimization Release

### Major Changes

#### Architecture Overhaul
- **Complete Docker Compose restructure** following modern best practices
- **Security-first approach** with all services running as non-root users
- **Resource optimization** with appropriate limits for Raspberry Pi
- **Health monitoring** with comprehensive health checks for all services
- **Centralized logging** using Loki Docker driver for all containers

#### Service Stack Updates
- **InfluxDB 2.7**: Upgraded with proper user permissions and health checks
- **Prometheus 2.48**: Enhanced with service discovery and retention policies
- **Loki 2.9**: New log aggregation system with 30-day retention
- **Alloy 0.38**: Modern telemetry collection replacing legacy agents
- **Telegraf 1.28**: Optimized system metrics collection
- **Grafana 10.2**: Latest version with pre-configured datasources

#### Network Architecture
- **Custom bridge network** (`skynet`) for service isolation
- **Service discovery** via Docker DNS
- **Proper dependency ordering** ensuring reliable startup sequence

#### Configuration Management
- **Environment-driven configuration** with comprehensive `.env.example`
- **Modular configuration files** in dedicated `configs/` directory
- **Automatic provisioning** for Grafana datasources and dashboards
- **Security token generation** with proper encryption

### Removed Features
- **Homarr service** completely removed as per requirements
- **Legacy configuration patterns** replaced with modern alternatives
- **Deprecated environment variables** cleaned up

### New Features

#### Comprehensive Logging
- **System log collection** (syslog, auth.log, kern.log)
- **Docker container logs** with automatic labeling
- **Application log monitoring** with service identification
- **Structured logging** with metadata and labels

#### Enhanced Monitoring
- **Multi-datasource support** (InfluxDB, Prometheus, Loki)
- **Real-time metrics** with 10-second collection intervals
- **Resource monitoring** with CPU, memory, disk, and network metrics
- **Container monitoring** with Docker-specific metrics

#### Security Improvements
- **Non-root execution** for all services
- **Resource limits** preventing system overload
- **Secure token management** with environment variables
- **Network isolation** with custom bridge networks

### Documentation
- **Complete documentation overhaul** with dedicated docs folder
- **Deployment guide** with step-by-step instructions
- **Configuration reference** with all available options
- **Troubleshooting guide** with common issues and solutions
- **Updated README** with modern architecture overview

### Configuration Files Added
- `configs/loki/loki.yml` - Loki configuration with retention policies
- `configs/grafana/grafana.ini` - Grafana server configuration
- `configs/grafana/provisioning/datasources/datasources.yml` - Auto-provisioned datasources
- `configs/grafana/provisioning/dashboards/dashboards.yml` - Dashboard provisioning
- `configs/influxdb/influxdb.conf` - InfluxDB server configuration

### Breaking Changes
- **Network name changed** from `monitoring-net` to `skynet`
- **Service dependencies** now properly defined with health checks
- **Environment variables** restructured for better organization
- **Homarr service removed** - users must migrate to alternative dashboards

### Migration Guide
1. **Backup existing data** before upgrading
2. **Update environment variables** using new `.env.example`
3. **Install Loki Docker plugin** before starting services
4. **Review new configuration files** in `configs/` directory
5. **Update any custom scripts** to use new service names

### System Requirements
- **Docker Engine 20.10+** with Docker Compose v2
- **ARM64 architecture support** for Raspberry Pi
- **Minimum 2GB RAM** (4GB recommended)
- **10GB free disk space** for data retention
- **Loki Docker plugin** installed

### Performance Improvements
- **Optimized resource allocation** for Raspberry Pi constraints
- **Efficient log collection** with Alloy replacing multiple agents
- **Better query performance** with proper datasource configuration
- **Reduced startup time** with optimized dependency ordering

### Security Enhancements
- **User isolation** with specific UIDs for each service
- **Resource constraints** preventing resource exhaustion
- **Secure defaults** with disabled unnecessary features
- **Token-based authentication** for all service communications

This release represents a complete modernization of the PiMonitor stack, focusing on reliability, security, and maintainability while following Docker and observability best practices.