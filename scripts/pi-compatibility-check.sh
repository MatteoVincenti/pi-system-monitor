#!/bin/bash
# Raspberry Pi Compatibility Check for PiMonitor
# Validates system compatibility and optimizes settings for Raspberry Pi

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# Raspberry Pi Compatibility Configuration
# =============================================================================

readonly PI_CHECK_VERSION="2.0.0"

# =============================================================================
# Compatibility Check Functions
# =============================================================================

# Display compatibility check banner
show_banner() {
    cat << 'EOF'
    ____  _   ______                            __  
   / __ \(_) / ____/___  ____ ___  ____  ____ _/ /_ 
  / /_/ / / / /   / __ \/ __ `__ \/ __ \/ __ `/ __/ 
 / ____/ / / /___/ /_/ / / / / / / /_/ / /_/ / /_   
/_/   /_/  \____/\____/_/ /_/ /_/ .___/\__,_/\__/   
                               /_/                  
PiMonitor Raspberry Pi Compatibility Check v2.0.0
EOF
    echo ""
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  -o, --optimize       Apply Raspberry Pi optimizations automatically
  -r, --report         Generate detailed compatibility report
  -f, --fix            Attempt to fix compatibility issues
  -v, --verbose        Verbose output with detailed information
  -h, --help           Show this help message

Compatibility Checks:
  Hardware:            CPU architecture, memory, storage
  Operating System:    Raspberry Pi OS compatibility
  Docker:              ARM64 image support and configuration
  Performance:         Resource limits and optimization settings
  Network:             Network configuration and performance

Examples:
  $0                   # Basic compatibility check
  $0 -o               # Check and apply optimizations
  $0 -r               # Generate detailed report
  $0 -f -o            # Fix issues and optimize
EOF
}

# Parse command line arguments
parse_args() {
    OPTIMIZE="false"
    GENERATE_REPORT="false"
    FIX_ISSUES="false"
    VERBOSE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--optimize)
                OPTIMIZE="true"
                shift
                ;;
            -r|--report)
                GENERATE_REPORT="true"
                shift
                ;;
            -f|--fix)
                FIX_ISSUES="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                export LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Detect Raspberry Pi model and specifications
detect_raspberry_pi() {
    log_info "Detecting Raspberry Pi hardware..."
    
    # Check if running on Raspberry Pi
    if [[ -f /proc/device-tree/model ]]; then
        PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
        IS_RASPBERRY_PI="true"
        log_info "Detected: $PI_MODEL"
    elif [[ -f /sys/firmware/devicetree/base/model ]]; then
        PI_MODEL=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0')
        IS_RASPBERRY_PI="true"
        log_info "Detected: $PI_MODEL"
    else
        IS_RASPBERRY_PI="false"
        PI_MODEL="Not a Raspberry Pi"
        log_warn "This does not appear to be a Raspberry Pi"
    fi
    
    # Get CPU information
    CPU_ARCHITECTURE=$(uname -m)
    CPU_CORES=$(nproc)
    
    # Get memory information
    TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEMORY_GB=$((TOTAL_MEMORY_KB / 1024 / 1024))
    
    # Get storage information
    ROOT_STORAGE=$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')
    
    log_debug "CPU Architecture: $CPU_ARCHITECTURE"
    log_debug "CPU Cores: $CPU_CORES"
    log_debug "Total Memory: ${TOTAL_MEMORY_GB}GB"
    log_debug "Root Storage: ${ROOT_STORAGE}GB"
}

# Check ARM64 compatibility
check_arm64_compatibility() {
    log_info "Checking ARM64 compatibility..."
    
    local compatibility_score=0
    local issues=()
    
    # Check CPU architecture
    case "$CPU_ARCHITECTURE" in
        "aarch64"|"arm64")
            log_info "✓ ARM64 architecture detected"
            ((compatibility_score += 25))
            ;;
        "armv7l"|"armhf")
            log_warn "⚠ ARM32 architecture detected - limited performance"
            issues+=("ARM32 architecture may have performance limitations")
            ((compatibility_score += 15))
            ;;
        "x86_64"|"amd64")
            log_info "✓ x86_64 architecture detected - full compatibility"
            ((compatibility_score += 25))
            ;;
        *)
            log_error "✗ Unsupported architecture: $CPU_ARCHITECTURE"
            issues+=("Unsupported CPU architecture: $CPU_ARCHITECTURE")
            ;;
    esac
    
    # Check if 64-bit kernel is running
    if [[ "$(getconf LONG_BIT)" == "64" ]]; then
        log_info "✓ 64-bit kernel detected"
        ((compatibility_score += 25))
    else
        log_warn "⚠ 32-bit kernel detected - consider upgrading to 64-bit"
        issues+=("32-bit kernel may limit performance and memory usage")
        ((compatibility_score += 10))
    fi
    
    ARM64_COMPATIBILITY_SCORE=$compatibility_score
    ARM64_ISSUES=("${issues[@]}")
}

# Check memory requirements
check_memory_requirements() {
    log_info "Checking memory requirements..."
    
    local memory_score=0
    local issues=()
    
    # Minimum requirements check
    if [[ $TOTAL_MEMORY_GB -ge 4 ]]; then
        log_info "✓ ${TOTAL_MEMORY_GB}GB RAM - Excellent for PiMonitor"
        memory_score=25
    elif [[ $TOTAL_MEMORY_GB -ge 2 ]]; then
        log_info "✓ ${TOTAL_MEMORY_GB}GB RAM - Good for PiMonitor"
        memory_score=20
    elif [[ $TOTAL_MEMORY_GB -ge 1 ]]; then
        log_warn "⚠ ${TOTAL_MEMORY_GB}GB RAM - Minimal for PiMonitor (reduce resource limits)"
        issues+=("Low memory: Consider reducing service memory limits")
        memory_score=10
    else
        log_error "✗ ${TOTAL_MEMORY_GB}GB RAM - Insufficient for PiMonitor"
        issues+=("Insufficient memory: PiMonitor requires at least 1GB RAM")
        memory_score=0
    fi
    
    # Check available memory
    local available_memory_kb
    available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local available_memory_gb=$((available_memory_kb / 1024 / 1024))
    
    if [[ $available_memory_gb -lt 1 ]]; then
        log_warn "⚠ Only ${available_memory_gb}GB memory currently available"
        issues+=("Low available memory: Consider closing other applications")
    fi
    
    # Check swap configuration
    local swap_total_kb
    swap_total_kb=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    local swap_total_gb=$((swap_total_kb / 1024 / 1024))
    
    if [[ $swap_total_gb -eq 0 ]]; then
        log_warn "⚠ No swap space configured - consider adding swap for stability"
        issues+=("No swap space: Consider adding swap file for memory stability")
    else
        log_info "✓ ${swap_total_gb}GB swap space configured"
    fi
    
    MEMORY_SCORE=$memory_score
    MEMORY_ISSUES=("${issues[@]}")
}

# Check storage requirements
check_storage_requirements() {
    log_info "Checking storage requirements..."
    
    local storage_score=0
    local issues=()
    
    # Check root filesystem space
    if [[ $ROOT_STORAGE -ge 32 ]]; then
        log_info "✓ ${ROOT_STORAGE}GB storage - Excellent for PiMonitor"
        storage_score=25
    elif [[ $ROOT_STORAGE -ge 16 ]]; then
        log_info "✓ ${ROOT_STORAGE}GB storage - Good for PiMonitor"
        storage_score=20
    elif [[ $ROOT_STORAGE -ge 8 ]]; then
        log_warn "⚠ ${ROOT_STORAGE}GB storage - Minimal for PiMonitor (monitor usage)"
        issues+=("Limited storage: Monitor disk usage and configure log rotation")
        storage_score=10
    else
        log_error "✗ ${ROOT_STORAGE}GB storage - Insufficient for PiMonitor"
        issues+=("Insufficient storage: PiMonitor requires at least 8GB free space")
        storage_score=0
    fi
    
    # Check storage type (SSD vs SD card)
    local root_device
    root_device=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//')
    
    if [[ "$root_device" =~ mmcblk ]]; then
        log_warn "⚠ Running on SD card - consider using SSD for better performance"
        issues+=("SD card storage: Consider using SSD for better I/O performance")
    elif [[ "$root_device" =~ nvme ]] || [[ "$root_device" =~ sda ]]; then
        log_info "✓ Running on SSD/NVMe - optimal for PiMonitor"
        ((storage_score += 5))
    fi
    
    # Check available space
    local available_space
    available_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if [[ $available_space -lt 5 ]]; then
        log_warn "⚠ Only ${available_space}GB free space available"
        issues+=("Low free space: Clean up disk space before deployment")
    fi
    
    STORAGE_SCORE=$storage_score
    STORAGE_ISSUES=("${issues[@]}")
}

# Check Docker compatibility
check_docker_compatibility() {
    log_info "Checking Docker compatibility..."
    
    local docker_score=0
    local issues=()
    
    # Check if Docker is installed
    if command_exists docker; then
        log_info "✓ Docker is installed"
        ((docker_score += 10))
        
        # Check Docker version
        local docker_version
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_debug "Docker version: $docker_version"
        
        # Check Docker Compose
        if docker compose version >/dev/null 2>&1; then
            log_info "✓ Docker Compose v2 is available"
            ((docker_score += 10))
        else
            log_error "✗ Docker Compose v2 is not available"
            issues+=("Docker Compose v2 required: Install Docker Compose v2")
        fi
        
        # Check Docker daemon status
        if docker info >/dev/null 2>&1; then
            log_info "✓ Docker daemon is running"
            ((docker_score += 5))
        else
            log_error "✗ Docker daemon is not running"
            issues+=("Docker daemon not running: Start Docker service")
        fi
        
        # Check Loki plugin
        if docker plugin ls 2>/dev/null | grep -q loki; then
            log_info "✓ Loki Docker plugin is installed"
            ((docker_score += 10))
        else
            log_warn "⚠ Loki Docker plugin not installed"
            issues+=("Loki plugin missing: Install with 'docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions'")
        fi
        
    else
        log_error "✗ Docker is not installed"
        issues+=("Docker not installed: Install Docker Engine")
    fi
    
    DOCKER_SCORE=$docker_score
    DOCKER_ISSUES=("${issues[@]}")
}

# Check network configuration
check_network_configuration() {
    log_info "Checking network configuration..."
    
    local network_score=0
    local issues=()
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_info "✓ Internet connectivity available"
        ((network_score += 10))
    else
        log_error "✗ No internet connectivity"
        issues+=("No internet access: Check network configuration")
    fi
    
    # Check DNS resolution
    if nslookup grafana.com >/dev/null 2>&1; then
        log_info "✓ DNS resolution working"
        ((network_score += 5))
    else
        log_warn "⚠ DNS resolution issues"
        issues+=("DNS issues: Check DNS configuration")
    fi
    
    # Check port availability
    local ports_to_check=(3000 8086 9090 3100 12345)
    local available_ports=0
    
    for port in "${ports_to_check[@]}"; do
        if is_port_available "$port"; then
            ((available_ports++))
        else
            issues+=("Port $port is in use: Change port or stop conflicting service")
        fi
    done
    
    if [[ $available_ports -eq ${#ports_to_check[@]} ]]; then
        log_info "✓ All required ports are available"
        ((network_score += 10))
    else
        log_warn "⚠ Some ports are in use: $((${#ports_to_check[@]} - available_ports)) conflicts"
    fi
    
    NETWORK_SCORE=$network_score
    NETWORK_ISSUES=("${issues[@]}")
}

# Apply Raspberry Pi optimizations
apply_pi_optimizations() {
    log_info "Applying Raspberry Pi optimizations..."
    
    local optimizations_applied=0
    
    # Create optimized environment configuration
    if [[ "$IS_RASPBERRY_PI" == "true" ]]; then
        log_info "Creating Raspberry Pi optimized configuration..."
        
        # Determine optimal resource limits based on memory
        local grafana_memory="256m"
        local influxdb_memory="512m"
        local prometheus_memory="256m"
        local loki_memory="256m"
        
        if [[ $TOTAL_MEMORY_GB -ge 4 ]]; then
            grafana_memory="512m"
            influxdb_memory="1g"
            prometheus_memory="512m"
            loki_memory="512m"
        elif [[ $TOTAL_MEMORY_GB -ge 2 ]]; then
            grafana_memory="384m"
            influxdb_memory="768m"
            prometheus_memory="384m"
            loki_memory="384m"
        fi
        
        # Create Pi-optimized environment file
        cat > "$PROJECT_ROOT/.env.pi-optimized" << EOF
# Raspberry Pi Optimized Configuration for PiMonitor
# Generated by pi-compatibility-check.sh on $(date)

# Project Configuration
COMPOSE_PROJECT_NAME=pimonitor
ENVIRONMENT=production

# Raspberry Pi Optimized Resource Limits
GRAFANA_MEMORY_LIMIT=$grafana_memory
INFLUXDB_MEMORY_LIMIT=$influxdb_memory
PROMETHEUS_MEMORY_LIMIT=$prometheus_memory
LOKI_MEMORY_LIMIT=$loki_memory
ALLOY_MEMORY_LIMIT=128m
TELEGRAF_MEMORY_LIMIT=128m

# CPU Limits (conservative for Pi)
GRAFANA_CPU_LIMIT=0.3
INFLUXDB_CPU_LIMIT=0.4
PROMETHEUS_CPU_LIMIT=0.3
LOKI_CPU_LIMIT=0.3
ALLOY_CPU_LIMIT=0.2
TELEGRAF_CPU_LIMIT=0.2

# Optimized Data Retention (shorter for Pi)
PROMETHEUS_RETENTION_TIME=15d
LOKI_RETENTION_PERIOD=15d
INFLUXDB_INIT_RETENTION=15d

# Performance Optimizations
PROMETHEUS_SCRAPE_INTERVAL=30s
TELEGRAF_INTERVAL=30s
LOKI_INGESTION_RATE_MB=8
LOKI_INGESTION_BURST_SIZE_MB=16

# Logging (reduced verbosity)
LOG_LEVEL=warn
GRAFANA_LOG_LEVEL=warn
INFLUXDB_LOG_LEVEL=warn
PROMETHEUS_LOG_LEVEL=warn
LOKI_LOG_LEVEL=warn

# Backup and Maintenance
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=14
AUTO_CLEANUP_ENABLED=true
EOF
        
        log_info "Created Pi-optimized configuration: .env.pi-optimized"
        ((optimizations_applied++))
    fi
    
    # Configure swap if not present and memory is low
    if [[ $TOTAL_MEMORY_GB -lt 4 ]] && [[ $(grep SwapTotal /proc/meminfo | awk '{print $2}') -eq 0 ]]; then
        log_info "Configuring swap file for low memory system..."
        
        cat > "$PROJECT_ROOT/setup-swap.sh" << 'EOF'
#!/bin/bash
# Setup swap file for Raspberry Pi
set -euo pipefail

SWAP_SIZE="2G"
SWAP_FILE="/swapfile"

echo "Creating ${SWAP_SIZE} swap file..."
sudo fallocate -l $SWAP_SIZE $SWAP_FILE
sudo chmod 600 $SWAP_FILE
sudo mkswap $SWAP_FILE
sudo swapon $SWAP_FILE

# Make swap permanent
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab
fi

echo "Swap file created and activated"
swapon --show
EOF
        
        chmod +x "$PROJECT_ROOT/setup-swap.sh"
        log_info "Created swap setup script: setup-swap.sh"
        ((optimizations_applied++))
    fi
    
    # Create Docker daemon optimization
    if [[ "$IS_RASPBERRY_PI" == "true" ]]; then
        cat > "$PROJECT_ROOT/docker-daemon-pi.json" << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3,
  "default-shm-size": "64m"
}
EOF
        
        log_info "Created Docker daemon optimization config: docker-daemon-pi.json"
        log_info "To apply: sudo cp docker-daemon-pi.json /etc/docker/daemon.json && sudo systemctl restart docker"
        ((optimizations_applied++))
    fi
    
    log_info "Applied $optimizations_applied Raspberry Pi optimizations"
}

# Fix compatibility issues
fix_compatibility_issues() {
    log_info "Attempting to fix compatibility issues..."
    
    local fixes_applied=0
    
    # Install Docker if missing
    if ! command_exists docker; then
        log_info "Installing Docker..."
        if curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; then
            sudo usermod -aG docker "$USER"
            rm get-docker.sh
            log_info "Docker installed successfully"
            ((fixes_applied++))
        else
            log_error "Failed to install Docker"
        fi
    fi
    
    # Install Loki plugin if missing
    if command_exists docker && ! docker plugin ls 2>/dev/null | grep -q loki; then
        log_info "Installing Loki Docker plugin..."
        
        local plugin_tag="latest"
        if [[ "$CPU_ARCHITECTURE" =~ ^(aarch64|arm64)$ ]]; then
            plugin_tag="3.3.2-arm64"
        fi
        
        if docker plugin install "grafana/loki-docker-driver:$plugin_tag" --alias loki --grant-all-permissions; then
            log_info "Loki Docker plugin installed successfully"
            ((fixes_applied++))
        else
            log_error "Failed to install Loki Docker plugin"
        fi
    fi
    
    log_info "Applied $fixes_applied compatibility fixes"
}

# Generate compatibility report
generate_compatibility_report() {
    local report_file="$PROJECT_ROOT/pi-compatibility-report-$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating compatibility report: $report_file"
    
    mkdir -p "$(dirname "$report_file")"
    
    local total_score=$((ARM64_COMPATIBILITY_SCORE + MEMORY_SCORE + STORAGE_SCORE + DOCKER_SCORE + NETWORK_SCORE))
    local max_score=110
    local compatibility_percentage=$((total_score * 100 / max_score))
    
    {
        echo "PiMonitor Raspberry Pi Compatibility Report"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Version: $PI_CHECK_VERSION"
        echo ""
        
        echo "Hardware Information:"
        echo "  Model: $PI_MODEL"
        echo "  Architecture: $CPU_ARCHITECTURE"
        echo "  CPU Cores: $CPU_CORES"
        echo "  Memory: ${TOTAL_MEMORY_GB}GB"
        echo "  Storage: ${ROOT_STORAGE}GB"
        echo ""
        
        echo "Compatibility Score: $total_score/$max_score ($compatibility_percentage%)"
        echo ""
        
        echo "Component Scores:"
        echo "  ARM64 Compatibility: $ARM64_COMPATIBILITY_SCORE/50"
        echo "  Memory Requirements: $MEMORY_SCORE/25"
        echo "  Storage Requirements: $STORAGE_SCORE/25"
        echo "  Docker Compatibility: $DOCKER_SCORE/35"
        echo "  Network Configuration: $NETWORK_SCORE/25"
        echo ""
        
        if [[ ${#ARM64_ISSUES[@]} -gt 0 ]] || [[ ${#MEMORY_ISSUES[@]} -gt 0 ]] || [[ ${#STORAGE_ISSUES[@]} -gt 0 ]] || [[ ${#DOCKER_ISSUES[@]} -gt 0 ]] || [[ ${#NETWORK_ISSUES[@]} -gt 0 ]]; then
            echo "Issues Found:"
            for issue in "${ARM64_ISSUES[@]}" "${MEMORY_ISSUES[@]}" "${STORAGE_ISSUES[@]}" "${DOCKER_ISSUES[@]}" "${NETWORK_ISSUES[@]}"; do
                echo "  - $issue"
            done
            echo ""
        fi
        
        echo "Recommendations:"
        if [[ $compatibility_percentage -ge 80 ]]; then
            echo "  - System is well-suited for PiMonitor"
            echo "  - Consider applying Pi optimizations for best performance"
        elif [[ $compatibility_percentage -ge 60 ]]; then
            echo "  - System can run PiMonitor with some limitations"
            echo "  - Apply optimizations and address identified issues"
        else
            echo "  - System may struggle with PiMonitor"
            echo "  - Address critical issues before deployment"
            echo "  - Consider hardware upgrades if possible"
        fi
        
    } > "$report_file"
    
    log_info "Compatibility report saved to: $report_file"
}

# Main compatibility check function
perform_compatibility_check() {
    log_info "Starting Raspberry Pi compatibility check..."
    
    # Detect hardware
    detect_raspberry_pi
    
    # Run compatibility checks
    check_arm64_compatibility
    check_memory_requirements
    check_storage_requirements
    check_docker_compatibility
    check_network_configuration
    
    # Calculate overall compatibility
    local total_score=$((ARM64_COMPATIBILITY_SCORE + MEMORY_SCORE + STORAGE_SCORE + DOCKER_SCORE + NETWORK_SCORE))
    local max_score=110
    local compatibility_percentage=$((total_score * 100 / max_score))
    
    echo ""
    log_info "=== Compatibility Summary ==="
    log_info "Overall Compatibility: $compatibility_percentage% ($total_score/$max_score)"
    
    if [[ $compatibility_percentage -ge 80 ]]; then
        log_info "✓ Excellent compatibility - Ready for PiMonitor deployment"
    elif [[ $compatibility_percentage -ge 60 ]]; then
        log_warn "⚠ Good compatibility - Some optimizations recommended"
    else
        log_error "✗ Limited compatibility - Address issues before deployment"
    fi
    
    # Apply fixes and optimizations if requested
    if [[ "$FIX_ISSUES" == "true" ]]; then
        fix_compatibility_issues
    fi
    
    if [[ "$OPTIMIZE" == "true" ]]; then
        apply_pi_optimizations
    fi
    
    # Generate report if requested
    if [[ "$GENERATE_REPORT" == "true" ]]; then
        generate_compatibility_report
    fi
    
    log_info "Raspberry Pi compatibility check completed"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    parse_args "$@"
    
    # Show banner
    show_banner
    
    # Create necessary directories
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Perform compatibility check
    perform_compatibility_check
}

# Run main function
main "$@"