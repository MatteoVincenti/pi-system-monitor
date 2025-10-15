# PiMonitor Deployment Guide

This comprehensive guide covers all aspects of deploying PiMonitor in different environments, from development to production.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Deployment Methods](#deployment-methods)
4. [Environment-Specific Configurations](#environment-specific-configurations)
5. [Security Considerations](#security-considerations)
6. [Performance Tuning](#performance-tuning)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

#### Minimum Requirements
- **CPU**: 2 cores (ARM64 or x86_64)
- **RAM**: 2GB (4GB recommended)
- **Storage**: 10GB free space (20GB recommended)
- **OS**: Linux (Ubuntu 20.04+, Debian 11+, Raspberry Pi OS)

#### Recommended Requirements
- **CPU**: 4 cores
- **RAM**: 4GB or more
- **Storage**: 50GB+ SSD storage
- **Network**: Stable internet connection for image downloads

### Software Prerequisites

#### Docker Installation
```bash
# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
```

#### Docker Compose v2
```bash
# Verify Docker Compose v2 is available
docker compose version

# If not available, install Docker Desktop or update Docker
```

#### Required Docker Plugins
```bash
# Install Loki Docker driver (required for log aggregation)
docker plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions

# Verify installation
docker plugin ls | grep loki
```

## Environment Setup

### 1. Repository Setup
```bash
# Clone the repository
git clone https://github.com/MatteoVincenti/PiMonitor.git
cd PiMonitor

# Verify directory structure
ls -la
```

### 2. Environment Configuration

#### Automated Configuration (Recommended)
```bash
# Run interactive setup
./scripts/setup.sh

# This will:
# - Validate system requirements
# - Install required plugins
# - Generate secure credentials
# - Create environment configuration
# - Set up directories and permissions
```

#### Manual Configuration
```bash
# Copy environment template
cp .env.example .env

# Generate secure credentials
./scripts/generate-secrets.sh

# Edit configuration
nano .env

# Validate configuration
./scripts/validate-config.sh development
```

### 3. Directory Structure
The setup process creates the following structure:
```
pimonitor/
├── configs/           # Service configurations
├── data/             # Persistent data (gitignored)
├── logs/             # Application logs
├── backups/          # Backup storage
├── secrets/          # Secure credentials (gitignored)
├── scripts/          # Management scripts
└── docs/             # Documentation
```

## Deployment Methods

### Method 1: Interactive Deployment (Recommended)
```bash
# Use the deployment manager
./scripts/deploy.sh start

# Select environment and options interactively
# The script will:
# - Validate configuration
# - Pull required images
# - Start services with health checks
# - Display service URLs and status
```

### Method 2: Environment-Specific Deployment
```bash
# Development environment
./scripts/deploy.sh start -e development

# Production environment
./scripts/deploy.sh start -e production

# Staging environment
./scripts/deploy.sh start -e staging

# With optional services
./scripts/deploy.sh start -e production -o
```

### Method 3: Direct Docker Compose
```bash
# Basic deployment
docker compose up -d

# With environment-specific overrides
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# With optional services
docker compose -f docker-compose.yml -f docker-compose.optional.yml up -d
```

## Enhanced Service Configurations

### Grafana Configuration Highlights

PiMonitor now includes a comprehensive Grafana configuration (`configs/grafana/grafana.ini`) that implements enterprise-grade security and performance optimizations:

#### Security Enhancements
- **Authentication hardening**: Disabled user registration and organization creation
- **Session security**: Secure cookie policies with SameSite protection
- **Brute force protection**: Built-in protection against login attacks  
- **XSS protection**: Content type validation and XSS headers
- **Privacy controls**: Gravatar disabled, external reporting disabled

#### Performance Optimizations
- **Compression**: Gzip enabled for faster page loads
- **Logging**: Structured logging with automatic rotation and 7-day retention
- **Resource management**: Optimized memory usage for Raspberry Pi
- **Caching**: Efficient dashboard and query caching

#### Professional Features
- **Unified alerting**: Modern alerting system with backward compatibility
- **Dashboard management**: Version control with 20-version history
- **Plugin security**: Controlled plugin loading with marketplace integration
- **Monitoring**: Internal metrics collection for performance tracking

#### Configuration Validation
```bash
# Validate Grafana configuration
./scripts/config-manager.sh validate production

# Check Grafana-specific settings
docker compose config grafana

# Test Grafana health after deployment
curl -f http://localhost:3000/api/health
```

## Environment-Specific Configurations

### Development Environment

#### Characteristics
- Relaxed security settings for ease of development
- Verbose logging for debugging
- Anonymous access enabled in Grafana
- Shorter data retention periods
- Higher resource limits for development tools

#### Configuration
```bash
# Use development environment file
cp .env.development .env

# Or set environment variable
export ENVIRONMENT=development

# Deploy
./scripts/deploy.sh start -e development
```

#### Development Features
- **Grafana**: Anonymous access, sign-up enabled, debug logging
- **Logging**: Debug level for all services
- **Resources**: Generous memory limits (1-2GB per service)
- **Retention**: 7-day data retention
- **Ports**: Standard ports (3000, 9090, 8086, 3100, 12345)

### Production Environment

#### Characteristics
- Strict security settings
- Optimized performance configurations
- Comprehensive monitoring and alerting
- Longer data retention periods
- Resource limits optimized for Raspberry Pi

#### Configuration
```bash
# Use production environment file
cp .env.production .env

# IMPORTANT: Update all passwords and tokens!
./scripts/generate-secrets.sh
nano .env  # Update GRAFANA_ADMIN_PASSWORD, etc.

# Validate production configuration
./scripts/validate-config.sh production --strict

# Deploy
./scripts/deploy.sh start -e production
```

#### Production Features
- **Enhanced Security**: 
  - No anonymous access or user registration
  - Brute force login protection enabled
  - XSS and content type protection
  - Secure cookie policies and session management
  - Comprehensive security headers
- **Optimized Performance**:
  - Gzip compression enabled
  - Structured logging with rotation (7-day retention)
  - Resource limits optimized for Raspberry Pi (512MB-1GB per service)
  - Minimal refresh intervals for dashboards
- **Advanced Monitoring**:
  - Unified alerting system with legacy compatibility
  - Internal metrics collection enabled
  - Comprehensive alerting rules with proper error handling
  - 90-day data retention across all services
- **Professional Features**:
  - Dashboard version control (20 versions retained)
  - Plugin management with security controls
  - Automated daily backups with integrity checks

#### Production Security Checklist
- [ ] Change all default passwords
- [ ] Generate secure tokens (32+ characters)
- [ ] Disable anonymous access in Grafana
- [ ] Enable HTTPS (if external access required)
- [ ] Set proper file permissions (600 for .env, 700 for secrets/)
- [ ] Configure firewall rules
- [ ] Set up regular backups
- [ ] Enable log monitoring and alerting

### Staging Environment

#### Characteristics
- Production-like settings for testing
- Balanced resource allocation
- Testing-friendly configurations
- Medium data retention periods

#### Configuration
```bash
# Use staging environment file
cp .env.staging .env

# Deploy
./scripts/deploy.sh start -e staging
```

## Security Considerations

### 1. Credential Management
```bash
# Generate secure credentials
./scripts/generate-secrets.sh

# Verify credential strength
./scripts/validate-config.sh production --strict

# Rotate credentials regularly
./scripts/generate-secrets.sh --rotate
```

### 2. Network Security
```bash
# Use custom Docker network (automatically configured)
docker network ls | grep pimonitor

# Restrict external access (production)
# Only expose necessary ports through firewall
sudo ufw allow 3000/tcp  # Grafana (if external access needed)
sudo ufw deny 9090/tcp   # Prometheus (internal only)
sudo ufw deny 8086/tcp   # InfluxDB (internal only)
```

### 3. File Permissions
```bash
# Set secure permissions
chmod 600 .env
chmod 700 secrets/
chmod 600 secrets/*.txt

# Verify permissions
./scripts/validate-config.sh --check-only
```

### 4. Container Security
All containers run with:
- Non-root users with specific UIDs
- Resource limits to prevent DoS
- Read-only configuration mounts
- Health checks for monitoring
- Proper capability dropping

## Performance Tuning

### 1. Resource Optimization

#### For Raspberry Pi 4 (4GB RAM)
```bash
# Use optimized production settings
export GRAFANA_MEMORY_LIMIT=512m
export INFLUXDB_MEMORY_LIMIT=1g
export PROMETHEUS_MEMORY_LIMIT=512m
export LOKI_MEMORY_LIMIT=512m
```

#### For Raspberry Pi 4 (8GB RAM)
```bash
# Use enhanced settings
export GRAFANA_MEMORY_LIMIT=1g
export INFLUXDB_MEMORY_LIMIT=2g
export PROMETHEUS_MEMORY_LIMIT=1g
export LOKI_MEMORY_LIMIT=1g
```

### 2. Storage Optimization
```bash
# Use SSD storage for better performance
# Mount SSD to /opt/pimonitor/data
sudo mkdir -p /opt/pimonitor/data
sudo chown $USER:$USER /opt/pimonitor/data

# Update data path in .env
echo "DATA_PATH=/opt/pimonitor/data" >> .env
```

### 3. Network Optimization
```bash
# Optimize Docker daemon for ARM64
sudo nano /etc/docker/daemon.json
```

Add:
```json
{
  "log-driver": "loki",
  "log-opts": {
    "loki-url": "http://localhost:3100/loki/api/v1/push"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
```

## Monitoring Deployment Health

### 1. Service Status
```bash
# Check all services
./scripts/deploy.sh status

# Check specific service
docker compose ps grafana

# View service logs
./scripts/logs.sh grafana -f
```

### 2. Health Checks
```bash
# Validate all configurations
./scripts/validate-config.sh all

# Check service health
curl -f http://localhost:3000/api/health  # Grafana
curl -f http://localhost:9090/-/healthy  # Prometheus
curl -f http://localhost:8086/health     # InfluxDB
curl -f http://localhost:3100/ready      # Loki
```

### 3. Performance Monitoring
```bash
# Check resource usage
docker stats

# Monitor system resources
./scripts/deploy.sh status

# Check disk usage
df -h
```

## Backup and Recovery

### 1. Automated Backups
```bash
# Enable automated backups
echo "BACKUP_ENABLED=true" >> .env
echo "BACKUP_SCHEDULE=0 2 * * *" >> .env  # Daily at 2 AM

# Manual backup
./scripts/backup.sh create production-backup
```

### 2. Backup Verification
```bash
# List backups
./scripts/backup.sh list

# Verify backup integrity
./scripts/backup.sh verify production-backup
```

### 3. Recovery Procedures
```bash
# Stop services
./scripts/deploy.sh stop

# Restore from backup
./scripts/backup.sh restore production-backup

# Start services
./scripts/deploy.sh start
```

## Troubleshooting

### Common Issues

#### 1. Loki Driver Not Found
```bash
# Install the driver
docker plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions

# Verify installation
docker plugin ls | grep loki
```

#### 2. Port Conflicts
```bash
# Check port usage
sudo netstat -tulpn | grep :3000

# Change ports in .env
echo "GRAFANA_PORT=3001" >> .env
./scripts/deploy.sh restart
```

#### 3. Memory Issues
```bash
# Check memory usage
free -h
docker stats

# Reduce memory limits
export GRAFANA_MEMORY_LIMIT=256m
export INFLUXDB_MEMORY_LIMIT=512m
./scripts/deploy.sh restart
```

#### 4. Service Won't Start
```bash
# Check service logs
./scripts/logs.sh service-name

# Validate configuration
./scripts/validate-config.sh

# Check dependencies
docker compose ps
```

### Advanced Troubleshooting

#### 1. Configuration Issues
```bash
# Comprehensive validation
./scripts/validate-config.sh all --verbose

# Fix common issues
./scripts/validate-config.sh --fix

# Generate validation report
./scripts/validate-config.sh all --report validation-report.html
```

#### 2. Performance Issues
```bash
# Check system resources
./scripts/deploy.sh status

# Monitor service performance
./scripts/logs.sh all -g "error\|warn"

# Optimize configuration
./scripts/config-manager.sh validate production
```

#### 3. Network Issues
```bash
# Check Docker network
docker network inspect pimonitor_monitoring

# Test service connectivity
docker compose exec grafana wget -qO- http://prometheus:9090/-/healthy
```

## Docker Resource Management

### Automated Cleanup

PiMonitor includes a comprehensive Docker cleanup system to maintain optimal resource usage:

```bash
# Safe cleanup (recommended for regular use)
./scripts/docker-cleanup.sh --safe

# Preview cleanup actions
./scripts/docker-cleanup.sh --dry-run

# Full cleanup with reporting
./scripts/docker-cleanup.sh --report

# Aggressive cleanup for space recovery
./scripts/docker-cleanup.sh --aggressive --force
```

### Cleanup Modes

| Mode | Description | Removes |
|------|-------------|---------|
| **Safe** | Conservative cleanup | Stopped containers, dangling images |
| **Normal** | Standard cleanup | + unused networks, dangling volumes |
| **Aggressive** | Maximum cleanup | + all unused images, build cache |

### Resource Monitoring

```bash
# Check Docker resource usage
docker system df

# Monitor container resources
docker stats --no-stream

# Check for cleanup opportunities
./scripts/docker-cleanup.sh --dry-run
```

### Automated Maintenance

Add to crontab for automated maintenance:
```bash
# Weekly safe Docker cleanup
0 2 * * 0 /path/to/pimonitor/scripts/docker-cleanup.sh --safe --force

# Monthly comprehensive system maintenance
0 3 1 * * /path/to/pimonitor/scripts/system-maintenance.sh --force

# Monthly comprehensive Docker cleanup with reporting
0 4 1 * * /path/to/pimonitor/scripts/docker-cleanup.sh --force --report
```

### System Maintenance

PiMonitor includes comprehensive system maintenance capabilities:

```bash
# Full system maintenance (recommended monthly)
./scripts/system-maintenance.sh

# System updates only
./scripts/system-maintenance.sh --update-only

# Cleanup only (includes Docker cleanup)
./scripts/system-maintenance.sh --clean-only

# Automated maintenance with auto-reboot
./scripts/system-maintenance.sh --force --reboot

# Preview what maintenance would do
./scripts/system-maintenance.sh --dry-run
```

**System Maintenance Features:**
- **Package updates** with security patches and system upgrades
- **Integrated Docker cleanup** using the enhanced cleanup script
- **Log management** with rotation and cleanup of old logs
- **Temporary file cleanup** to free disk space
- **Automatic reboot handling** for kernel updates
- **Comprehensive reporting** with system health metrics

## Maintenance

### Regular Maintenance Tasks

#### Daily
- Monitor service health via Grafana dashboards
- Check for any error logs
- Verify backup completion

#### Weekly
- Review resource usage trends
- Check for available updates
- Clean up old logs and temporary files
- Run safe Docker cleanup: `./scripts/docker-cleanup.sh --safe --force`

#### Monthly
- Rotate credentials and tokens
- Review and update alerting rules
- Perform backup restoration tests
- Update Docker images
- Run comprehensive system maintenance: `./scripts/system-maintenance.sh --force`
- Run comprehensive Docker cleanup: `./scripts/docker-cleanup.sh --force --report`

### Update Procedures
```bash
# Update images and restart services
./scripts/deploy.sh update

# Update with backup
./scripts/backup.sh create pre-update
./scripts/deploy.sh update
```

### Scaling Considerations

#### Horizontal Scaling
For larger deployments, consider:
- Multiple Prometheus instances with federation
- Loki clustering for high availability
- Load balancing for Grafana
- Separate InfluxDB instances for different metrics

#### Vertical Scaling
For single-node scaling:
- Increase memory limits based on available RAM
- Use faster storage (NVMe SSD)
- Optimize retention periods
- Tune query performance settings

## Support and Resources

### Getting Help
1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review service logs: `./scripts/logs.sh service-name`
3. Validate configuration: `./scripts/validate-config.sh`
4. Generate diagnostic report: `./scripts/validate-config.sh --report`

### Additional Resources
- [Configuration Reference](configuration.md)
- [Migration Guide](MIGRATION.md)
- [Performance Tuning Guide](performance-tuning.md)
- [Security Best Practices](security.md)