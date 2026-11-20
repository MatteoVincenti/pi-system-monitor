#!/bin/bash
# Raspberry Pi Compatibility Check for PiMonitor
# Validates system requirements and ARM64 compatibility

# Source common utilities
TEMP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$TEMP_SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Raspberry Pi Compatibility Constants
# =============================================================================

readonly PI_CHECK_VERSION="2.0.0"
readonly MIN_MEMORY_GB=2
readonly MIN_DISK_GB=10
readonly MIN_DOCKER_VERSION="20.10.0"
readonly REQUIRED_ARCH="aarch64"

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
Raspberry Pi Compatibility Check v2.0.0
EOF
    echo ""
}

# Check Raspberry Pi model and specifications
check_pi_model() {
    log_info "Checking Raspberry Pi model and specifications..."
    
    local pi_model=""
    local pi_memory=""
    local pi_revision=""
    
    # Check if running on Raspberry Pi
    if [[ -f /proc/cpuinfo ]]; then
        pi_model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
        pi_revision=$(grep "Revision" /proc/cpuinfo | cut -d: -f2 | xargs)
    fi
    
    if [[ -z "$pi_model" ]]; then
        log_warn "Not running on a Raspberry Pi or model detection failed"
        log_info "System: $(uname -a)"
        return 0
    fi
    
    log_info "Raspberry Pi Model: $pi_model"
    log_info "Revision: $pi_revision"
    
    # Check memory from /proc/meminfo
    local total_memory_kb
    total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_gb=$((total_memory_kb / 1024 / 1024))
    
    log_info "Total Memory: ${total_memory_gb}GB"
    
    # Validate minimum requirements
    if [[ $total_memory_gb -lt $MIN_MEMORY_GB ]]; then
        log_error "Insufficient memory: ${total_memory_gb}GB (minimum: ${MIN_MEMORY_GB}GB)"
        log_warn "PiMonitor may experience performance issues or out-of-memory errors"
        return 1
    else
        log_info "Memory requirement satisfied: ${total_memory_gb}GB >= ${MIN_MEMORY_GB}GB"
    fi
    
    # Check for specific Pi models and provide recommendations
    case "$pi_model" in
        *"Raspberry Pi 4"*)
            log_info "✅ Raspberry Pi 4 detected - Excellent compatibility"
            if [[ $total_memory_gb -ge 4 ]]; then
                log_info "✅ 4GB+ RAM - Recommended for full PiMonitor stack"
            elif [[ $total_memory_gb -ge 2 ]]; then
                log_info "⚠️  2GB RAM - Adequate but consider memory optimization"
            fi
            ;;
        *"Raspberry Pi 3"*)
            log_warn "⚠️  Raspberry Pi 3 detected - Limited compatibility"
            log_warn "Consider upgrading to Pi 4 for better performance"
            ;;
        *"Raspberry Pi 5"*)
            log_info "✅ Raspberry Pi 5 detected - Excellent compatibility"
            log_info "✅ Latest hardware - Optimal performance expected"
            ;;
        *)
            log_warn "Unknown or older Raspberry Pi model: $pi_model"
            log_warn "Compatibility not guaranteed"
            ;;
    esac
    
    return 0
}

# Check system architecture
check_architecture() {
    log_info "Checking system architecture..."
    
    local arch
    arch=$(uname -m)
    
    log_info "System Architecture: $arch"
    
    case "$arch" in
        "aarch64"|"arm64")
            log_info "✅ ARM64 architecture detected - Full compatibility"
            return 0
            ;;
        "armv7l"|"armhf")
            log_warn "⚠️  ARM32 architecture detected - Limited compatibility"
            log_warn "Some Docker images may not be available for ARM32"
            log_warn "Consider using Raspberry Pi OS 64-bit for better compatibility"
            return 1
            ;;
        "x86_64"|"amd64")
            log_info "✅ x86_64 architecture detected - Full compatibility"
            log_info "Note: Not a Raspberry Pi, but PiMonitor will work"
            return 0
            ;;
        *)
            log_error "❌ Unsupported architecture: $arch"
            log_error "PiMonitor requires ARM64 or x86_64 architecture"
            return 1
            ;;
    esac
}

# Check operating system compatibility
check_operating_system() {
    log_info "Checking operating system compatibility..."
    
    local os_info
    os_info=$(get_os_info)
    
    log_info "Operating System: $os_info"
    
    # Check for supported OS
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        
        case "$ID" in
            "raspbian"|"debian")
                log_info "✅ Debian-based OS detected - Excellent compatibility"
                if [[ "$VERSION_ID" ]]; then
                    log_info "Version: $VERSION_ID"
                fi
                ;;
            "ubuntu")
                log_info "✅ Ubuntu detected - Excellent compatibility"
                log_info "Version: $VERSION_ID"
                ;;
            "fedora"|"centos"|"rhel")
                log_info "✅ Red Hat-based OS detected - Good compatibility"
                log_info "Version: $VERSION_ID"
                ;;
            *)
                log_warn "⚠️  Unknown OS: $ID"
                log_warn "Compatibility not guaranteed"
                ;;
        esac
        
        # Check for 64-bit OS on ARM
        if [[ "$arch" == "aarch64" ]] && [[ "$os_info" == *"32-bit"* ]]; then
            log_warn "⚠️  32-bit OS detected on 64-bit hardware"
            log_warn "Consider upgrading to 64-bit OS for better performance"
        fi
    else
        log_warn "Cannot determine OS version"
    fi
    
    return 0
}

# Check Docker compatibility
check_docker_compatibility() {
    log_info "Checking Docker compatibility..."
    
    if ! command_exists docker; then
        log_error "❌ Docker not installed"
        log_info "Install Docker with: curl -fsSL https://get.docker.com | sh"
        return 1
    fi
    
    local docker_version
    docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    log_info "Docker Version: $docker_version"
    
    # Check minimum Docker version
    if ! version_compare "$docker_version" "$MIN_DOCKER_VERSION"; then
        log_error "❌ Docker version too old: $docker_version (minimum: $MIN_DOCKER_VERSION)"
        log_info "Update Docker with: curl -fsSL https://get.docker.com | sh"
        return 1
    else
        log_info "✅ Docker version requirement satisfied"
    fi
    
    # Check Docker Compose v2
    if ! docker compose version >/dev/null 2>&1; then
        log_error "❌ Docker Compose v2 not available"
        log_info "Install Docker Compose v2 or update Docker"
        return 1
    else
        local compose_version
        compose_version=$(docker compose version --short)
        log_info "✅ Docker Compose v2 available: $compose_version"
    fi
    
    # Check Docker daemon status
    if ! docker info >/dev/null 2>&1; then
        log_error "❌ Docker daemon not running or not accessible"
        log_info "Start Docker: sudo systemctl start docker"
        log_info "Enable Docker: sudo systemctl enable docker"
        return 1
    else
        log_info "✅ Docker daemon is running"
    fi
    
    # Check user permissions
    if ! docker ps >/dev/null 2>&1; then
        log_warn "⚠️  User not in docker group"
        log_info "Add user to docker group: sudo usermod -aG docker $USER"
        log_info "Then log out and back in"
        return 1
    else
        log_info "✅ Docker permissions are correct"
    fi
    
    return 0
}

# Check storage requirements
check_storage_requirements() {
    log_info "Checking storage requirements..."
    
    local available_space_gb
    available_space_gb=$(df "$PROJECT_ROOT" | awk 'NR==2{print int($4/1024/1024)}')
    
    log_info "Available Disk Space: ${available_space_gb}GB"
    
    if [[ $available_space_gb -lt $MIN_DISK_GB ]]; then
        log_error "❌ Insufficient disk space: ${available_space_gb}GB (minimum: ${MIN_DISK_GB}GB)"
        log_info "Free up disk space or use external storage"
        return 1
    else
        log_info "✅ Disk space requirement satisfied: ${available_space_gb}GB >= ${MIN_DISK_GB}GB"
    fi
    
    # Check for SD card vs SSD
    local root_device
    root_device=$(df / | awk 'NR==2{print $1}' | sed 's/[0-9]*$//')
    
    if [[ "$root_device" == *"mmcblk"* ]]; then
        log_warn "⚠️  Running on SD card storage"
        log_warn "Consider using SSD storage for better I/O performance"
        log_info "Recommendation: Use USB 3.0 SSD for data directory"
    else
        log_info "✅ Using non-SD card storage (better performance)"
    fi
    
    return 0
}

# Check network requirements
check_network_requirements() {
    log_info "Checking network requirements..."
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "❌ No internet connectivity"
        log_info "Internet required for Docker image downloads"
        return 1
    else
        log_info "✅ Internet connectivity available"
    fi
    
    # Check DNS resolution
    if ! nslookup docker.io >/dev/null 2>&1; then
        log_warn "⚠️  DNS resolution issues detected"
        log_info "May affect Docker image downloads"
    else
        log_info "✅ DNS resolution working"
    fi
    
    return 0
}

# Check ARM64 Docker image availability
check_arm64_images() {
    log_info "Checking ARM64 Docker image availability..."
    
    local images=(
        "grafana/grafana-oss:10.2.0"
        "influxdb:2.7-alpine"
        "prom/prometheus:v2.48.0"
        "grafana/loki:2.9.0"
        "grafana/alloy:v0.38.0"
        "telegraf:1.28-alpine"
    )
    
    local unavailable_images=()
    
    for image in "${images[@]}"; do
        log_debug "Checking image: $image"
        
        # Try to inspect the image manifest for ARM64 support
        if docker manifest inspect "$image" >/dev/null 2>&1; then
            if docker manifest inspect "$image" | grep -q "arm64\|aarch64"; then
                log_debug "✅ $image supports ARM64"
            else
                log_warn "⚠️  $image may not support ARM64"
                unavailable_images+=("$image")
            fi
        else
            log_warn "⚠️  Cannot check manifest for $image"
        fi
    done
    
    if [[ ${#unavailable_images[@]} -eq 0 ]]; then
        log_info "✅ All required images support ARM64"
        return 0
    else
        log_warn "⚠️  Some images may not support ARM64:"
        for image in "${unavailable_images[@]}"; do
            log_warn "  - $image"
        done
        return 1
    fi
}

# Check system performance
check_system_performance() {
    log_info "Checking system performance characteristics..."
    
    # Check CPU information
    local cpu_cores
    cpu_cores=$(nproc)
    log_info "CPU Cores: $cpu_cores"
    
    if [[ $cpu_cores -lt 2 ]]; then
        log_warn "⚠️  Single core CPU detected - may impact performance"
    else
        log_info "✅ Multi-core CPU available"
    fi
    
    # Check CPU frequency (if available)
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        local cpu_freq
        cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        cpu_freq=$((cpu_freq / 1000))  # Convert to MHz
        log_info "CPU Frequency: ${cpu_freq}MHz"
    fi
    
    # Check system load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    log_info "Current Load Average: $load_avg"
    
    # Check swap
    local swap_total
    swap_total=$(free -h | awk '/^Swap:/ {print $2}')
    if [[ "$swap_total" == "0B" ]]; then
        log_warn "⚠️  No swap configured - consider enabling swap for memory management"
        log_info "Enable swap: sudo dphys-swapfile setup && sudo dphys-swapfile swapon"
    else
        log_info "✅ Swap available: $swap_total"
    fi
    
    return 0
}

# Version comparison function
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Simple version comparison (assumes semantic versioning)
    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    # Fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    
    return 0
}

# Generate compatibility report
generate_compatibility_report() {
    local report_file="${1:-pi-compatibility-report.txt}"
    
    log_info "Generating compatibility report: $report_file"
    
    {
        echo "Raspberry Pi Compatibility Report for PiMonitor"
        echo "=============================================="
        echo "Generated: $(date)"
        echo "Check Version: $PI_CHECK_VERSION"
        echo ""
        
        echo "System Information:"
        echo "------------------"
        echo "Hostname: $(hostname)"
        echo "OS: $(get_os_info)"
        echo "Architecture: $(uname -m)"
        echo "Kernel: $(uname -r)"
        echo ""
        
        if [[ -f /proc/cpuinfo ]]; then
            echo "Raspberry Pi Information:"
            echo "------------------------"
            grep -E "(Model|Revision|Serial)" /proc/cpuinfo
            echo ""
        fi
        
        echo "Hardware Resources:"
        echo "------------------"
        echo "CPU Cores: $(nproc)"
        echo "Memory: $(free -h | awk 'NR==2{print $2}')"
        echo "Disk Space: $(df -h "$PROJECT_ROOT" | awk 'NR==2{print $4}')"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        
        echo "Docker Information:"
        echo "------------------"
        if command_exists docker; then
            echo "Docker Version: $(docker --version)"
            if docker compose version >/dev/null 2>&1; then
                echo "Docker Compose: $(docker compose version --short)"
            else
                echo "Docker Compose: Not available"
            fi
        else
            echo "Docker: Not installed"
        fi
        echo ""
        
        echo "Network Information:"
        echo "-------------------"
        echo "IP Address: $(hostname -I | awk '{print $1}')"
        echo "Internet: $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "Available" || echo "Not available")"
        echo ""
        
    } > "$report_file"
    
    log_info "Compatibility report saved to: $report_file"
}

# Provide optimization recommendations
provide_recommendations() {
    log_info "Optimization Recommendations:"
    echo "=============================="
    
    local arch
    arch=$(uname -m)
    
    # Architecture-specific recommendations
    case "$arch" in
        "aarch64"|"arm64")
            echo "✅ ARM64 Architecture Recommendations:"
            echo "  - Use ARM64-specific Docker images when available"
            echo "  - Enable Docker BuildKit for better ARM64 support"
            echo "  - Consider using multi-arch images for compatibility"
            ;;
        "armv7l"|"armhf")
            echo "⚠️  ARM32 Architecture Recommendations:"
            echo "  - Upgrade to Raspberry Pi OS 64-bit if possible"
            echo "  - Use ARM32-compatible images (may be limited)"
            echo "  - Consider hardware upgrade to Pi 4 or newer"
            ;;
    esac
    
    # Memory recommendations
    local memory_gb
    memory_gb=$(free -g | awk 'NR==2{print $2}')
    
    if [[ $memory_gb -le 2 ]]; then
        echo ""
        echo "💾 Memory Optimization (${memory_gb}GB RAM):"
        echo "  - Enable swap file for memory management"
        echo "  - Use memory-optimized PiMonitor configuration"
        echo "  - Consider reducing service memory limits"
        echo "  - Monitor memory usage regularly"
    elif [[ $memory_gb -le 4 ]]; then
        echo ""
        echo "💾 Memory Management (${memory_gb}GB RAM):"
        echo "  - Use standard PiMonitor configuration"
        echo "  - Monitor memory usage during peak loads"
        echo "  - Consider enabling swap as backup"
    else
        echo ""
        echo "💾 Memory Configuration (${memory_gb}GB RAM):"
        echo "  - Use full PiMonitor configuration"
        echo "  - Can increase service memory limits if needed"
        echo "  - Excellent for development and testing"
    fi
    
    # Storage recommendations
    local root_device
    root_device=$(df / | awk 'NR==2{print $1}' | sed 's/[0-9]*$//')
    
    if [[ "$root_device" == *"mmcblk"* ]]; then
        echo ""
        echo "💽 Storage Optimization (SD Card):"
        echo "  - Consider using USB 3.0 SSD for better I/O"
        echo "  - Move Docker data directory to SSD"
        echo "  - Enable log rotation to prevent SD card wear"
        echo "  - Use high-quality SD card (Class 10, A2)"
    else
        echo ""
        echo "💽 Storage Configuration (SSD/HDD):"
        echo "  - Excellent storage performance expected"
        echo "  - Can use standard retention policies"
        echo "  - Consider RAID for redundancy if multiple drives"
    fi
    
    # Network recommendations
    echo ""
    echo "🌐 Network Optimization:"
    echo "  - Use wired Ethernet for better stability"
    echo "  - Configure static IP for consistent access"
    echo "  - Open firewall ports for external access if needed"
    echo "  - Consider VPN for secure remote access"
    
    # Docker recommendations
    echo ""
    echo "🐳 Docker Optimization:"
    echo "  - Enable Docker daemon logging to journald"
    echo "  - Configure Docker to start on boot"
    echo "  - Use Docker Compose v2 for better performance"
    echo "  - Regular cleanup of unused images and containers"
    
    echo ""
}

# Main compatibility check function
run_compatibility_check() {
    local errors=0
    
    show_banner
    
    log_info "Running comprehensive Raspberry Pi compatibility check..."
    echo ""
    
    # Run all compatibility checks
    check_pi_model || ((errors++))
    echo ""
    
    check_architecture || ((errors++))
    echo ""
    
    check_operating_system || ((errors++))
    echo ""
    
    check_docker_compatibility || ((errors++))
    echo ""
    
    check_storage_requirements || ((errors++))
    echo ""
    
    check_network_requirements || ((errors++))
    echo ""
    
    check_arm64_images || ((errors++))
    echo ""
    
    check_system_performance || ((errors++))
    echo ""
    
    # Generate report
    generate_compatibility_report
    echo ""
    
    # Provide recommendations
    provide_recommendations
    echo ""
    
    # Summary
    if [[ $errors -eq 0 ]]; then
        log_info "🎉 Compatibility check passed! Your system is ready for PiMonitor."
        log_info "Run './scripts/setup.sh' to begin installation."
    elif [[ $errors -le 2 ]]; then
        log_warn "⚠️  Compatibility check completed with $errors warnings."
        log_warn "Your system should work but may have performance limitations."
        log_info "Review the recommendations above and run './scripts/setup.sh' to proceed."
    else
        log_error "❌ Compatibility check failed with $errors errors."
        log_error "Please address the issues above before installing PiMonitor."
        return 1
    fi
    
    return 0
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse arguments
    case "${1:-}" in
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help     Show this help message"
            echo "  -r, --report   Generate detailed compatibility report"
            echo ""
            echo "This script checks Raspberry Pi compatibility for PiMonitor."
            exit 0
            ;;
        -r|--report)
            generate_compatibility_report "detailed-pi-compatibility-report.txt"
            exit 0
            ;;
        "")
            run_compatibility_check
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"