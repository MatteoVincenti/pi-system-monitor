#!/bin/bash
set -euo pipefail

# Generate secure secrets for PiMonitor services
# This script creates random passwords and tokens for secure deployment

SECRETS_DIR="./secrets"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    log_error "openssl is required but not installed. Please install openssl first."
    exit 1
fi

# Create secrets directory if it doesn't exist
mkdir -p "$SECRETS_DIR"

# Generate Grafana admin password
GRAFANA_PASSWORD_FILE="$SECRETS_DIR/grafana_admin_password.txt"
if [[ ! -f "$GRAFANA_PASSWORD_FILE" ]]; then
    openssl rand -base64 32 > "$GRAFANA_PASSWORD_FILE"
    chmod 600 "$GRAFANA_PASSWORD_FILE"
    log_info "Generated Grafana admin password: $GRAFANA_PASSWORD_FILE"
else
    log_warn "Grafana admin password already exists: $GRAFANA_PASSWORD_FILE"
fi

# Generate InfluxDB admin token
INFLUXDB_TOKEN_FILE="$SECRETS_DIR/influxdb_admin_token.txt"
if [[ ! -f "$INFLUXDB_TOKEN_FILE" ]]; then
    openssl rand -hex 32 > "$INFLUXDB_TOKEN_FILE"
    chmod 600 "$INFLUXDB_TOKEN_FILE"
    log_info "Generated InfluxDB admin token: $INFLUXDB_TOKEN_FILE"
else
    log_warn "InfluxDB admin token already exists: $INFLUXDB_TOKEN_FILE"
fi

# Generate Prometheus web config for basic auth (optional)
PROMETHEUS_WEB_CONFIG="$SECRETS_DIR/prometheus_web_config.yml"
if [[ ! -f "$PROMETHEUS_WEB_CONFIG" ]]; then
    # Generate bcrypt hash for 'admin' user with random password
    PROMETHEUS_PASSWORD=$(openssl rand -base64 16)
    PROMETHEUS_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$PROMETHEUS_PASSWORD', bcrypt.gensalt()).decode())" 2>/dev/null || echo "")
    
    if [[ -n "$PROMETHEUS_HASH" ]]; then
        cat > "$PROMETHEUS_WEB_CONFIG" << EOF
basic_auth_users:
  admin: $PROMETHEUS_HASH
EOF
        echo "$PROMETHEUS_PASSWORD" > "$SECRETS_DIR/prometheus_admin_password.txt"
        chmod 600 "$PROMETHEUS_WEB_CONFIG" "$SECRETS_DIR/prometheus_admin_password.txt"
        log_info "Generated Prometheus web config: $PROMETHEUS_WEB_CONFIG"
        log_info "Prometheus admin password: $SECRETS_DIR/prometheus_admin_password.txt"
    else
        log_warn "Python3 with bcrypt not available. Skipping Prometheus web config generation."
    fi
fi

log_info "Secret generation completed!"
log_info "Remember to:"
log_info "  1. Keep these files secure and never commit them to version control"
log_info "  2. Backup these files in a secure location"
log_info "  3. Update your .env file with appropriate references to these secrets"

# Display generated passwords for initial setup
echo
log_info "Generated credentials (save these securely):"
if [[ -f "$GRAFANA_PASSWORD_FILE" ]]; then
    echo "  Grafana Admin Password: $(cat "$GRAFANA_PASSWORD_FILE")"
fi
if [[ -f "$INFLUXDB_TOKEN_FILE" ]]; then
    echo "  InfluxDB Admin Token: $(cat "$INFLUXDB_TOKEN_FILE")"
fi
if [[ -f "$SECRETS_DIR/prometheus_admin_password.txt" ]]; then
    echo "  Prometheus Admin Password: $(cat "$SECRETS_DIR/prometheus_admin_password.txt")"
fi