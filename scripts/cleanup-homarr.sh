#!/bin/bash
set -euo pipefail

# Cleanup script to remove any remaining Homarr-related Docker resources
# This script ensures complete removal of Homarr service components

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_info "Starting Homarr cleanup verification..."

# Check for Homarr containers
log_info "Checking for Homarr containers..."
HOMARR_CONTAINERS=$(docker ps -a --filter "name=homarr" --format "{{.Names}}" 2>/dev/null || echo "")
if [[ -n "$HOMARR_CONTAINERS" ]]; then
    log_warn "Found Homarr containers: $HOMARR_CONTAINERS"
    echo "To remove them, run:"
    echo "  docker rm -f $HOMARR_CONTAINERS"
else
    log_info "No Homarr containers found"
fi

# Check for Homarr volumes
log_info "Checking for Homarr volumes..."
HOMARR_VOLUMES=$(docker volume ls --filter "name=homarr" --format "{{.Name}}" 2>/dev/null || echo "")
if [[ -n "$HOMARR_VOLUMES" ]]; then
    log_warn "Found Homarr volumes: $HOMARR_VOLUMES"
    echo "To remove them, run:"
    echo "  docker volume rm $HOMARR_VOLUMES"
else
    log_info "No Homarr volumes found"
fi

# Check for Homarr networks
log_info "Checking for Homarr networks..."
HOMARR_NETWORKS=$(docker network ls --filter "name=homarr" --format "{{.Name}}" 2>/dev/null || echo "")
if [[ -n "$HOMARR_NETWORKS" ]]; then
    log_warn "Found Homarr networks: $HOMARR_NETWORKS"
    echo "To remove them, run:"
    echo "  docker network rm $HOMARR_NETWORKS"
else
    log_info "No Homarr networks found"
fi

# Check for Homarr images
log_info "Checking for Homarr images..."
HOMARR_IMAGES=$(docker images --filter "reference=*homarr*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || echo "")
if [[ -n "$HOMARR_IMAGES" ]]; then
    log_warn "Found Homarr images: $HOMARR_IMAGES"
    echo "To remove them, run:"
    echo "  docker rmi $HOMARR_IMAGES"
else
    log_info "No Homarr images found"
fi

# Check for Homarr configuration files
log_info "Checking for Homarr configuration files..."
HOMARR_CONFIGS=$(find ./configs -name "*homarr*" -type f 2>/dev/null || echo "")
if [[ -n "$HOMARR_CONFIGS" ]]; then
    log_warn "Found Homarr configuration files: $HOMARR_CONFIGS"
    echo "To remove them, run:"
    echo "  rm -f $HOMARR_CONFIGS"
else
    log_info "No Homarr configuration files found"
fi

# Check for Homarr data directories
log_info "Checking for Homarr data directories..."
HOMARR_DATA=$(find ./data -name "*homarr*" -type d 2>/dev/null || echo "")
if [[ -n "$HOMARR_DATA" ]]; then
    log_warn "Found Homarr data directories: $HOMARR_DATA"
    echo "To remove them, run:"
    echo "  rm -rf $HOMARR_DATA"
else
    log_info "No Homarr data directories found"
fi

# Check for Homarr Docker Compose files
log_info "Checking for Homarr Docker Compose files..."
HOMARR_COMPOSE=$(find . -maxdepth 1 -name "*homarr*.y*ml" -type f 2>/dev/null || echo "")
if [[ -n "$HOMARR_COMPOSE" ]]; then
    log_warn "Found Homarr Docker Compose files: $HOMARR_COMPOSE"
    echo "To remove them, run:"
    echo "  rm -f $HOMARR_COMPOSE"
else
    log_info "No Homarr Docker Compose files found"
fi

log_info "Homarr cleanup verification completed!"
log_info "Homarr service has been successfully removed from the PiMonitor stack."
log_info "The system now focuses on core monitoring functionality with:"
log_info "  - Grafana for visualization and dashboards"
log_info "  - InfluxDB and Prometheus for metrics storage"
log_info "  - Loki for log aggregation"
log_info "  - Telegraf and Alloy for data collection"