# PiMonitor Troubleshooting Guide

This comprehensive guide helps you diagnose and resolve common issues with PiMonitor deployment and operation.

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Common Issues](#common-issues)
3. [Service-Specific Issues](#service-specific-issues)
4. [Performance Issues](#performance-issues)
5. [Configuration Issues](#configuration-issues)
6. [Network Issues](#network-issues)
7. [Storage Issues](#storage-issues)
8. [Advanced Troubleshooting](#advanced-troubleshooting)

## Quick Diagnostics

### Health Check Commands
```bash
# Overall system status
./scripts/deploy.sh status

# Service health checks
curl -f http://localhost:3000/api/health    # Grafana
curl -f http://localhost:9090/-/healthy     # Prometheus
curl -f http://localhost:8086/health        # InfluxDB
curl -f http://localhost:3100/ready         # Loki
curl -f http://localhost:12345/-/healthy    # Alloy

# Configuration validation
./scripts/validate-config.sh all

# Docker system information
docker system info
docker compose ps
```

### Log Analysis
```bash
# View all service logs
./scripts/logs.sh all

# View specific service logs
./scripts/logs.sh grafana -f

# Search for errors
./scripts/logs.sh all -e

# Search for specific patterns
./scripts/logs.sh all -g "error\|failed\|timeout"
```

### Resource Monitoring
```bash
# System resources
free -h
df -h
top

# Docker resources
docker stats
docker system df

# Service resource usage
./scripts/deploy.sh status
```

## Common Issues

### 1. Loki Docker Driver Not Found

#### Symptoms
- Services fail to start with logging errors
- Error: "failed to initialize logging driver"
- Docker Compose shows logging driver errors

#### Diagnosis
```bash
# Check if Loki plugin is installed
docker plugin ls | grep loki

# Check plugin status
docker plugin inspect loki
```

#### Solution
```bash
# Install Loki Docker plugin
docker plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions

# For x86_64 systems
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions

# Verify installation
docker plugin ls | grep loki

# Restart services
./scripts/deploy.sh restart
```

### 2. Port Conflicts

#### Symptoms
- Services fail to start
- "Port already in use" errors
- Cannot access web interfaces

#### Diagnosis
```bash
# Check port usage
sudo netstat -tulpn | grep :3000
sudo lsof -i :3000

# Check all PiMonitor ports
for port in 3000 8086 9090 3100 12345; do
    echo "Port $port:"
    sudo netstat -tulpn | grep :$port
done
```

#### Solution
```bash
# Option 1: Stop conflicting services
sudo systemctl stop service-using-port

# Option 2: Change PiMonitor ports
echo "GRAFANA_PORT=3001" >> .env
echo "INFLUXDB_PORT=8087" >> .env
echo "PROMETHEUS_PORT=9091" >> .env

# Restart services
./scripts/deploy.sh restart
```

### 3. Memory Issues

#### Symptoms
- Services getting killed (OOMKilled)
- Slow performance
- System becomes unresponsive

#### Diagnosis
```bash
# Check memory usage
free -h
docker stats

# Check for OOMKilled containers
docker compose ps -a
dmesg | grep -i "killed process"

# Check swap usage
swapon --show
```

#### Solution
```bash
# Reduce memory limits
export GRAFANA_MEMORY_LIMIT=256m
export INFLUXDB_MEMORY_LIMIT=512m
export PROMETHEUS_MEMORY_LIMIT=256m
export LOKI_MEMORY_LIMIT=256m

# Enable swap (if not already enabled)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Restart services with new limits
./scripts/deploy.sh restart
```

### 4. Permission Issues

#### Symptoms
- "Permission denied" errors
- Services cannot write to volumes
- Configuration files cannot be read

#### Diagnosis
```bash
# Check file permissions
ls -la .env
ls -la secrets/
ls -la data/

# Check Docker socket permissions
ls -la /var/run/docker.sock

# Check user groups
groups $USER
```

#### Solution
```bash
# Fix file permissions
chmod 600 .env
chmod 700 secrets/
chmod 600 secrets/*.txt
sudo chown -R $USER:$USER data/

# Add user to docker group (if needed)
sudo usermod -aG docker $USER
# Log out and back in for group changes

# Fix Docker socket permissions (if needed)
sudo chmod 666 /var/run/docker.sock

# Restart services
./scripts/deploy.sh restart
```

### 5. Service Startup Failures

#### Symptoms
- Services exit immediately after starting
- Health checks fail
- Services stuck in "starting" state

#### Diagnosis
```bash
# Check service status
docker compose ps

# Check service logs
./scripts/logs.sh service-name

# Check configuration
./scripts/validate-config.sh

# Check dependencies
docker compose config --services
```

#### Solution
```bash
# Validate and fix configuration
./scripts/validate-config.sh --fix

# Check for missing dependencies
./scripts/deploy.sh validate

# Restart in correct order
./scripts/deploy.sh stop
./scripts/deploy.sh start

# If persistent, recreate containers
docker compose down
docker compose up -d --force-recreate
```

## Service-Specific Issues

### Grafana Issues

#### Cannot Access Grafana Web Interface

**Symptoms:**
- Browser shows "connection refused"
- Grafana container is running but not accessible
- "502 Bad Gateway" or timeout errors

**Diagnosis:**
```bash
# Check Grafana status and health
docker compose ps grafana
curl -f http://localhost:3000/api/health

# Check port binding and configuration
docker port pimonitor_grafana
grep GRAFANA_PORT .env

# Check Grafana logs for startup errors
./scripts/logs.sh grafana | grep -i "error\|failed\|panic"

# Test internal connectivity
docker compose exec grafana wget -qO- http://localhost:3000/api/health
```

**Solution:**
```bash
# Validate Grafana configuration
./scripts/config-manager.sh validate production

# Check for port conflicts
sudo netstat -tulpn | grep :3000

# Restart Grafana with clean state
docker compose stop grafana
docker compose rm -f grafana
docker compose up -d grafana

# Check firewall (if accessing remotely)
sudo ufw status
sudo ufw allow 3000/tcp

# Monitor startup process
./scripts/logs.sh grafana -f
```

#### Grafana Login Issues

**Symptoms:**
- Cannot login with admin credentials
- "Invalid username or password" errors
- Account lockout due to brute force protection

**Diagnosis:**
```bash
# Check admin credentials configuration
grep -E "GRAFANA_ADMIN_(USER|PASSWORD)" .env

# Check for brute force protection triggers
./scripts/logs.sh grafana | grep -i "brute\|login\|auth"

# Verify Grafana security settings
docker compose exec grafana cat /etc/grafana/grafana.ini | grep -A 10 "\[security\]"
```

**Solution:**
```bash
# Reset admin password with secure generation
./scripts/generate-secrets.sh

# Update environment and restart
source .env
docker compose restart grafana

# Check generated credentials
echo "Username: $(grep GRAFANA_ADMIN_USER .env | cut -d= -f2)"
echo "Password: $(cat secrets/grafana_admin_password.txt)"

# If brute force protection is active, wait or restart Grafana
docker compose restart grafana

# Verify login works
curl -u admin:$(cat secrets/grafana_admin_password.txt) \
     http://localhost:3000/api/admin/stats
```

#### Grafana Configuration Issues

**Symptoms:**
- Grafana starts but features don't work as expected
- Security settings not applied
- Performance issues or high memory usage

**Diagnosis:**
```bash
# Check Grafana configuration validation
./scripts/config-manager.sh validate production

# Verify configuration file is properly mounted
docker compose exec grafana cat /etc/grafana/grafana.ini | head -20

# Check for configuration errors in logs
./scripts/logs.sh grafana | grep -i "config\|setting\|invalid"

# Verify security settings are active
curl -I http://localhost:3000/ | grep -i "x-\|content-"
```

**Solution:**
```bash
# Regenerate Grafana configuration from template
./scripts/config-manager.sh generate production

# Validate the generated configuration
docker compose exec grafana grafana-cli admin reset-admin-password \
    --config=/etc/grafana/grafana.ini \
    $(cat secrets/grafana_admin_password.txt)

# Restart with fresh configuration
docker compose stop grafana
docker compose up -d grafana

# Verify configuration is loaded correctly
./scripts/logs.sh grafana | grep -i "config.*loaded"
```

#### Grafana Dashboard Issues

**Symptoms:**
- Dashboards not loading or showing "No data"
- Datasource connection errors
- Query timeouts or performance issues

**Diagnosis:**
```bash
# Check datasource connectivity from Grafana
curl -u admin:$(cat secrets/grafana_admin_password.txt) \
     http://localhost:3000/api/datasources

# Test datasource connections
docker compose exec grafana wget -qO- http://prometheus:9090/-/healthy
docker compose exec grafana wget -qO- http://influxdb:8086/health
docker compose exec grafana wget -qO- http://loki:3100/ready

# Check for query errors in logs
./scripts/logs.sh grafana | grep -i "query\|datasource\|timeout"
```

**Solution:**
```bash
# Restart datasource services first
docker compose restart prometheus influxdb loki
sleep 30

# Then restart Grafana
docker compose restart grafana

# Re-provision datasources if needed
docker compose exec grafana curl -X POST \
    -H "Content-Type: application/json" \
    -u admin:$(cat secrets/grafana_admin_password.txt) \
    http://localhost:3000/api/admin/provisioning/datasources/reload

# Check dashboard provisioning
ls -la configs/grafana/dashboards/
./scripts/logs.sh grafana | grep -i "dashboard.*provision"
```

#### Grafana Performance Issues

**Symptoms:**
- Slow dashboard loading
- High memory usage
- Query timeouts

**Diagnosis:**
```bash
# Check Grafana resource usage
docker stats pimonitor_grafana --no-stream

# Check for memory-intensive queries
./scripts/logs.sh grafana | grep -i "memory\|slow\|timeout"

# Monitor query performance
curl -u admin:$(cat secrets/grafana_admin_password.txt) \
     http://localhost:3000/api/admin/stats
```

**Solution:**
```bash
# Increase Grafana memory limits
export GRAFANA_MEMORY_LIMIT=1g
export GRAFANA_MEMORY_RESERVATION=512m

# Optimize Grafana configuration for performance
echo "GRAFANA_MIN_REFRESH_INTERVAL=10s" >> .env
echo "GRAFANA_QUERY_TIMEOUT=60s" >> .env

# Restart with new settings
docker compose restart grafana

# Enable query caching if available
./scripts/logs.sh grafana | grep -i "cache"
```

#### Grafana Security Issues

**Symptoms:**
- Security headers not present
- Unauthorized access attempts
- Configuration not following security best practices

**Diagnosis:**
```bash
# Check security headers
curl -I http://localhost:3000/ | grep -E "(X-|Content-Security|Strict-Transport)"

# Check security configuration
docker compose exec grafana cat /etc/grafana/grafana.ini | grep -A 20 "\[security\]"

# Check for security-related log entries
./scripts/logs.sh grafana | grep -i "security\|auth\|unauthorized"
```

**Solution:**
```bash
# Validate security configuration
./scripts/config-manager.sh validate production

# Ensure security settings are properly configured
grep -E "(GRAFANA_.*SECURE|GRAFANA_.*PROTECTION)" .env

# Restart Grafana to apply security settings
docker compose restart grafana

# Verify security headers are present
curl -I http://localhost:3000/ | grep -i security

# Check that anonymous access is disabled (production)
curl http://localhost:3000/api/org | grep -i anonymous
```

### InfluxDB Issues

#### InfluxDB Initialization Failures

**Symptoms:**
- InfluxDB fails to start
- "setup not allowed" errors
- Database not initialized

**Diagnosis:**
```bash
# Check InfluxDB logs
./scripts/logs.sh influxdb

# Check initialization settings
grep INFLUXDB_INIT .env

# Check data directory
ls -la data/influxdb/
```

**Solution:**
```bash
# Remove existing data (WARNING: This deletes all data)
docker compose down
sudo rm -rf data/influxdb/

# Regenerate tokens
./scripts/generate-secrets.sh

# Restart with fresh initialization
./scripts/deploy.sh start
```

#### InfluxDB Connection Issues

**Symptoms:**
- Telegraf cannot connect to InfluxDB
- "connection refused" errors in Telegraf logs

**Diagnosis:**
```bash
# Check InfluxDB health
curl -f http://localhost:8086/health

# Check network connectivity
docker compose exec telegraf wget -qO- http://influxdb:8086/health

# Check InfluxDB logs
./scripts/logs.sh influxdb
```

**Solution:**
```bash
# Verify InfluxDB configuration
./scripts/validate-config.sh

# Check token validity
curl -H "Authorization: Token $INFLUXDB_ADMIN_TOKEN" \
     http://localhost:8086/api/v2/buckets

# Restart services in order
docker compose restart influxdb
sleep 30
docker compose restart telegraf
```

### Prometheus Issues

#### Prometheus Target Down

**Symptoms:**
- Targets show as "DOWN" in Prometheus UI
- No metrics being collected

**Diagnosis:**
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Prometheus configuration
./scripts/validate-config.sh

# Check target connectivity
docker compose exec prometheus wget -qO- http://grafana:3000/metrics
```

**Solution:**
```bash
# Validate Prometheus configuration
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Restart Prometheus
docker compose restart prometheus

# Check service discovery
./scripts/logs.sh prometheus | grep -i discovery
```

### Loki Issues

#### Loki Log Ingestion Problems

**Symptoms:**
- No logs appearing in Grafana
- Loki ingestion errors
- High memory usage in Loki

**Diagnosis:**
```bash
# Check Loki health
curl http://localhost:3100/ready

# Check Loki metrics
curl http://localhost:3100/metrics | grep loki_ingester

# Check Alloy logs
./scripts/logs.sh alloy
```

**Solution:**
```bash
# Check Loki configuration
./scripts/validate-config.sh

# Increase Loki memory limits
export LOKI_MEMORY_LIMIT=1g
docker compose restart loki

# Check log ingestion rate
curl http://localhost:3100/loki/api/v1/label/job/values
```

### Alloy Issues

#### Alloy Not Collecting Logs

**Symptoms:**
- No logs in Loki from Alloy
- Alloy shows connection errors

**Diagnosis:**
```bash
# Check Alloy status
curl http://localhost:12345/-/healthy

# Check Alloy configuration
./scripts/logs.sh alloy

# Test Loki connectivity from Alloy
docker compose exec alloy wget -qO- http://loki:3100/ready
```

**Solution:**
```bash
# Validate Alloy configuration
./scripts/validate-config.sh

# Restart Alloy
docker compose restart alloy

# Check file permissions for log files
ls -la /var/log/
```

## Performance Issues

### Slow Query Performance

#### Symptoms
- Grafana dashboards load slowly
- Prometheus queries timeout
- High CPU usage

#### Diagnosis
```bash
# Check resource usage
docker stats

# Check query performance
./scripts/logs.sh prometheus | grep -i "query\|slow"
./scripts/logs.sh grafana | grep -i "query\|slow"

# Check system load
uptime
iostat 1 5
```

#### Solution
```bash
# Optimize query intervals
export PROMETHEUS_SCRAPE_INTERVAL=30s
export TELEGRAF_INTERVAL=30s

# Increase memory limits
export PROMETHEUS_MEMORY_LIMIT=1g
export GRAFANA_MEMORY_LIMIT=1g

# Optimize retention periods
export PROMETHEUS_RETENTION_TIME=15d
export LOKI_RETENTION_PERIOD=15d

# Restart services
./scripts/deploy.sh restart
```

### High Memory Usage

#### Symptoms
- System running out of memory
- Services being killed
- Swap usage high

#### Diagnosis
```bash
# Monitor memory usage over time
watch -n 5 'free -h && echo "---" && docker stats --no-stream'

# Check memory leaks
./scripts/logs.sh all | grep -i "memory\|oom"

# Check for memory-intensive queries
./scripts/logs.sh prometheus | grep -i "query.*memory"
```

#### Solution
```bash
# Reduce memory limits
export GRAFANA_MEMORY_LIMIT=256m
export INFLUXDB_MEMORY_LIMIT=512m
export PROMETHEUS_MEMORY_LIMIT=256m
export LOKI_MEMORY_LIMIT=256m

# Optimize configurations
export PROMETHEUS_RETENTION_TIME=7d
export LOKI_RETENTION_PERIOD=7d
export LOKI_INGESTION_RATE_MB=16

# Enable memory monitoring
export ENABLE_RESOURCE_MONITORING=true
export MEMORY_WARNING_THRESHOLD=75

# Restart with new settings
./scripts/deploy.sh restart
```

### Disk Space Issues

#### Symptoms
- "No space left on device" errors
- Services cannot write data
- Slow I/O performance

#### Diagnosis
```bash
# Check disk usage
df -h
du -sh data/*

# Check Docker space usage
docker system df

# Check log file sizes
du -sh logs/*

# Preview what Docker cleanup would remove
./scripts/docker-cleanup.sh --dry-run
```

#### Solution
```bash
# Safe Docker cleanup (recommended first step)
./scripts/docker-cleanup.sh --safe

# Normal Docker cleanup with confirmation
./scripts/docker-cleanup.sh

# Aggressive cleanup for severe space issues
./scripts/docker-cleanup.sh --aggressive --force

# Generate cleanup report for analysis
./scripts/docker-cleanup.sh --report

# Clean up old logs
./scripts/logs.sh --clear

# Reduce retention periods
export PROMETHEUS_RETENTION_TIME=7d
export LOKI_RETENTION_PERIOD=7d
export LOG_RETENTION_DAYS=7

# Enable automatic cleanup
export AUTO_CLEANUP_ENABLED=true
export CLEANUP_SCHEDULE="0 2 * * *"

# Move data to larger disk (if available)
sudo mkdir -p /mnt/storage/pimonitor
sudo chown $USER:$USER /mnt/storage/pimonitor
echo "DATA_PATH=/mnt/storage/pimonitor" >> .env

# Restart services
./scripts/deploy.sh restart
```

## Configuration Issues

### Environment Variable Problems

#### Symptoms
- Services use default values instead of configured ones
- Configuration validation fails
- Inconsistent behavior between environments

#### Diagnosis
```bash
# Check environment file syntax
bash -n .env

# Validate configuration
./scripts/validate-config.sh all --verbose

# Check variable expansion
docker compose config | grep -A 5 -B 5 "environment:"
```

#### Solution
```bash
# Fix syntax errors
./scripts/validate-config.sh --fix

# Regenerate configuration
cp .env.example .env
./scripts/generate-secrets.sh

# Validate and restart
./scripts/validate-config.sh production
./scripts/deploy.sh restart
```

### Docker Compose Issues

#### Symptoms
- "service not found" errors
- Compose file validation fails
- Services don't start in correct order

#### Diagnosis
```bash
# Validate compose files
docker compose config --quiet

# Check service dependencies
docker compose config --services

# Check for syntax errors
./scripts/validate-config.sh --check-only
```

#### Solution
```bash
# Fix compose file syntax
./scripts/validate-config.sh --fix

# Recreate services with dependencies
docker compose down
docker compose up -d --remove-orphans

# Check service startup order
./scripts/logs.sh all | grep -i "started\|ready"
```

## Network Issues

### Service Communication Problems

#### Symptoms
- Services cannot reach each other
- "connection refused" between services
- Network timeouts

#### Diagnosis
```bash
# Check Docker network
docker network ls | grep pimonitor
docker network inspect pimonitor_monitoring

# Test service connectivity
docker compose exec grafana wget -qO- http://prometheus:9090/-/healthy
docker compose exec telegraf wget -qO- http://influxdb:8086/health

# Check DNS resolution
docker compose exec grafana nslookup prometheus
```

#### Solution
```bash
# Recreate network
docker compose down
docker network rm pimonitor_monitoring
docker compose up -d

# Check network configuration
./scripts/validate-config.sh

# Restart services
./scripts/deploy.sh restart
```

### External Access Issues

#### Symptoms
- Cannot access services from other machines
- Firewall blocking connections
- DNS resolution problems

#### Diagnosis
```bash
# Check port bindings
docker compose ps
netstat -tulpn | grep -E "(3000|8086|9090|3100|12345)"

# Check firewall status
sudo ufw status

# Test external connectivity
telnet your-pi-ip 3000
```

#### Solution
```bash
# Configure firewall
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus (if needed)

# Check Docker daemon configuration
sudo systemctl status docker

# Restart Docker daemon (if needed)
sudo systemctl restart docker
./scripts/deploy.sh start
```

## Docker Resource Management

### Docker Cleanup Operations

PiMonitor includes a comprehensive Docker cleanup script that helps maintain system health by removing unused resources while protecting running services.

#### Safe Cleanup
Removes only stopped containers and dangling images:
```bash
./scripts/docker-cleanup.sh --safe
```

#### Normal Cleanup
Removes stopped containers, unused images, networks, and dangling volumes:
```bash
./scripts/docker-cleanup.sh
```

#### Aggressive Cleanup
Removes all unused resources including build cache (use with caution):
```bash
./scripts/docker-cleanup.sh --aggressive
```

#### Dry Run Analysis
Preview what would be cleaned without making changes:
```bash
./scripts/docker-cleanup.sh --dry-run
```

#### Automated Cleanup
For scripts and automation, use force mode:
```bash
./scripts/docker-cleanup.sh --force --report
```

#### Cleanup Reports
Generate detailed reports of cleanup operations:
```bash
./scripts/docker-cleanup.sh --report
# Report saved to logs/docker-cleanup-YYYYMMDD_HHMMSS.txt
```

### Docker Resource Monitoring

#### Check Resource Usage
```bash
# Current Docker disk usage
docker system df

# Detailed breakdown
docker system df -v

# Container resource usage
docker stats --no-stream

# Check for unused resources
docker images --filter "dangling=true"
docker volume ls --filter "dangling=true"
docker network ls --filter "dangling=true"
```

#### Preventive Maintenance
```bash
# Weekly safe cleanup (recommended)
./scripts/docker-cleanup.sh --safe --force

# Monthly comprehensive system maintenance
./scripts/system-maintenance.sh --force

# Monthly normal Docker cleanup
./scripts/docker-cleanup.sh --force

# Monitor disk usage trends
watch -n 60 'docker system df'
```

## Advanced Troubleshooting

### Debug Mode

#### Enable Debug Logging
```bash
# Temporary debug mode
export LOG_LEVEL=debug
./scripts/deploy.sh restart

# Permanent debug mode
echo "LOG_LEVEL=debug" >> .env
echo "DEV_ENABLE_DEBUG_LOGGING=true" >> .env
./scripts/deploy.sh restart
```

#### Collect Debug Information
```bash
# Generate comprehensive debug report
./scripts/validate-config.sh all --report debug-report.html

# Collect system information
./scripts/deploy.sh status > system-status.txt
docker system info > docker-info.txt
free -h > memory-info.txt
df -h > disk-info.txt

# Collect service logs
./scripts/logs.sh all > all-services.log
```

### Performance Profiling

#### Monitor Resource Usage
```bash
# Continuous monitoring
watch -n 5 'docker stats --no-stream'

# Log resource usage
while true; do
    echo "$(date): $(docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}')"
    sleep 60
done > resource-usage.log
```

#### Profile Specific Services
```bash
# Grafana profiling (if enabled)
curl http://localhost:3000/debug/pprof/

# Prometheus profiling
curl http://localhost:9090/debug/pprof/

# System profiling
top -b -n 1 > system-profile.txt
iostat -x 1 5 > io-profile.txt
```

### Recovery Procedures

#### Complete System Recovery
```bash
# Stop all services
./scripts/deploy.sh stop

# Backup current state
./scripts/backup.sh create emergency-backup

# Reset to clean state
docker compose down --volumes --remove-orphans
docker system prune -af

# Restore from backup (if available)
./scripts/backup.sh restore last-known-good

# Or start fresh
./scripts/setup.sh
```

#### Service-Specific Recovery
```bash
# Reset specific service
docker compose stop grafana
docker compose rm -f grafana
docker volume rm pimonitor_grafana-data
docker compose up -d grafana

# Restore service from backup
./scripts/backup.sh restore service-backup grafana
```

### Getting Help

#### Collect Information for Support
```bash
# System information
uname -a > system-info.txt
docker version >> system-info.txt
docker compose version >> system-info.txt

# Configuration information
./scripts/validate-config.sh all --verbose > config-validation.txt

# Service status
./scripts/deploy.sh status > service-status.txt

# Recent logs
./scripts/logs.sh all --since 1h > recent-logs.txt

# Create support package
tar -czf pimonitor-support-$(date +%Y%m%d_%H%M%S).tar.gz \
    system-info.txt config-validation.txt service-status.txt recent-logs.txt .env.example
```

#### Common Support Resources
1. **Configuration Validation**: `./scripts/validate-config.sh all --verbose`
2. **Service Logs**: `./scripts/logs.sh service-name`
3. **System Status**: `./scripts/deploy.sh status`
4. **Health Checks**: Run all curl commands from Quick Diagnostics
5. **Documentation**: Check [Configuration Reference](configuration.md) and [Deployment Guide](deployment.md)

### Prevention

#### Regular Maintenance
```bash
# Weekly health check
./scripts/validate-config.sh all
./scripts/deploy.sh status

# Monthly cleanup
./scripts/backup.sh cleanup
docker system prune -f

# Update monitoring
./scripts/deploy.sh update
```

#### Monitoring Setup
```bash
# Enable comprehensive monitoring
export ENABLE_RESOURCE_MONITORING=true
export ENABLE_SELF_MONITORING=true
export ENABLE_DETAILED_METRICS=true

# Set up alerting thresholds
export MEMORY_WARNING_THRESHOLD=80
export DISK_WARNING_THRESHOLD=85
export CPU_WARNING_THRESHOLD=80

# Restart with monitoring
./scripts/deploy.sh restart
```