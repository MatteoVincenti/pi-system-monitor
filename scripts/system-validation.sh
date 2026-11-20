#!/bin/bash
# PiMonitor System Validation Script
# Comprehensive validation for Raspberry Pi deployment

# Source shared libraries
TEMP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$TEMP_SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/docker.sh
source "$TEMP_SCRIPT_DIR/lib/docker.sh"
# shellcheck source=./lib/validation.sh
source "$TEMP_SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# Validation Configuration
# =============================================================================

readonly VALIDATION_VERSION="2.0.0"

# =============================================================================
# System Validation Functions
# =============================================================================

# Display validation banner
show_banner() {
    cat << 'EOF'
   _____            __                 _    __      ___     __      __  _           
  / ___/__  _______/ /____  ____ ___  | |  / /___ _/ (_)___/ /___ _/ /_(_)___  ____ 
  \__ \/ / / / ___/ __/ _ \/ __ `__ \ | | / / __ `/ / / __  / __ `/ __/ / __ \/ __ \
 ___/ / /_/ (__  ) /_/  __/ / / / / / | |/ / /_/ / / / /_/ / /_/ / /_/ / /_/ / / / /
/____/\__, /____/\__/\___/_/ /_/ /_/  |___/\__,_/_/_/\__,_/\__,_/\__/_/\____/_/ /_/ 
     /____/                                                                        
PiMonitor System Validation v2.0.0
EOF
    echo ""
}

# Comprehensive system validation
validate_system() {
    log_info "Running comprehensive system validation for PiMonitor..."
    
    local validation_errors=0
    
    # 1. Raspberry Pi compatibility check
    log_info "Step 1: Raspberry Pi Compatibility"
    if ! "$SCRIPT_DIR/pi-compatibility-check.sh" >/dev/null 2>&1; then
        log_warn "Raspberry Pi compatibility check found issues"
        ((validation_errors++))
    else
        log_info "✅ Raspberry Pi compatibility verified"
    fi
    echo ""
    
    # 2. Docker system validation
    log_info "Step 2: Docker System Validation"
    if ! validate_docker || ! validate_docker_compose || ! validate_docker_plugins; then
        log_error "Docker system validation failed"
        ((validation_errors++))
    else
        log_info "✅ Docker system validated"
    fi
    echo ""
    
    # 3. Environment configuration validation
    log_info "Step 3: Environment Configuration Validation"
    if ! validate_environment; then
        log_error "Environment validation failed"
        ((validation_errors++))
    else
        log_info "✅ Environment configuration validated"
    fi
    echo ""
    
    # 4. Service configuration validation
    log_info "Step 4: Service Configuration Validation"
    if ! validate_service_configs; then
        log_error "Service configuration validation failed"
        ((validation_errors++))
    else
        log_info "✅ Service configurations validated"
    fi
    echo ""
    
    # 5. Port availability check
    log_info "Step 5: Port Availability Check"
    if ! validate_port_availability; then
        log_error "Port availability check failed"
        ((validation_errors++))
    else
        log_info "✅ All required ports are available"
    fi
    echo ""
    
    # 6. File permissions check
    log_info "Step 6: File Permissions Check"
    if ! check_file_permissions; then
        log_error "File permissions check failed"
        ((validation_errors++))
    else
        log_info "✅ File permissions are correct"
    fi
    echo ""
    
    # 7. ARM64 image availability check
    log_info "Step 7: ARM64 Image Availability Check"
    if ! check_arm64_image_availability; then
        log_warn "Some ARM64 images may not be available"
        # Don't count as error, just warning
    else
        log_info "✅ ARM64 images are available"
    fi
    echo ""
    
    return $validation_errors
}

# Check file permissions
check_file_permissions() {
    log_debug "Checking file permissions..."
    
    local permission_errors=0
    
    # Check .env file permissions
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        local env_perms
        env_perms=$(stat -c %a "$PROJECT_ROOT/.env" 2>/dev/null)
        if [[ "$env_perms" != "600" ]]; then
            log_error "Incorrect .env file permissions: $env_perms (should be 600)"
            ((permission_errors++))
        fi
    fi
    
    # Check secrets directory permissions
    if [[ -d "$PROJECT_ROOT/secrets" ]]; then
        local secrets_perms
        secrets_perms=$(stat -c %a "$PROJECT_ROOT/secrets" 2>/dev/null)
        if [[ "$secrets_perms" != "700" ]]; then
            log_error "Incorrect secrets directory permissions: $secrets_perms (should be 700)"
            ((permission_errors++))
        fi
        
        # Check individual secret files
        find "$PROJECT_ROOT/secrets" -name "*.txt" -type f | while read -r secret_file; do
            local file_perms
            file_perms=$(stat -c %a "$secret_file" 2>/dev/null)
            if [[ "$file_perms" != "600" ]]; then
                log_error "Incorrect secret file permissions: $(basename "$secret_file") ($file_perms, should be 600)"
                ((permission_errors++))
            fi
        done
    fi
    
    # Check script permissions
    find "$PROJECT_ROOT/scripts" -name "*.sh" -type f | while read -r script_file; do
        if [[ ! -x "$script_file" ]]; then
            log_error "Script not executable: $(basename "$script_file")"
            ((permission_errors++))
        fi
    done
    
    return $permission_errors
}

# Check ARM64 image availability
check_arm64_image_availability() {
    log_debug "Checking ARM64 image availability..."
    
    local images=(
        "grafana/grafana-oss:10.2.0"
        "influxdb:2.7-alpine"
        "prom/prometheus:v2.48.0"
        "grafana/loki:2.9.0"
        "grafana/alloy:v0.38.0"
        "telegraf:1.28-alpine"
    )
    
    local unavailable_count=0
    
    for image in "${images[@]}"; do
        log_debug "Checking ARM64 support for: $image"
        
        # Try to pull the image manifest
        if docker manifest inspect "$image" >/dev/null 2>&1; then
            if docker manifest inspect "$image" | grep -q "arm64\|aarch64"; then
                log_debug "✅ $image supports ARM64"
            else
                log_warn "⚠️  $image may not support ARM64"
                ((unavailable_count++))
            fi
        else
            log_warn "⚠️  Cannot verify ARM64 support for $image"
            ((unavailable_count++))
        fi
    done
    
    if [[ $unavailable_count -eq 0 ]]; then
        return 0
    else
        log_warn "$unavailable_count images may have ARM64 compatibility issues"
        return 1
    fi
}

# Test Docker functionality
test_docker_functionality() {
    log_info "Testing Docker functionality..."
    
    # Test basic Docker operations
    if ! docker run --rm alpine:latest echo "Docker test successful" >/dev/null 2>&1; then
        log_error "❌ Basic Docker functionality test failed"
        return 1
    else
        log_info "✅ Basic Docker functionality working"
    fi
    
    # Test Docker Compose
    local test_compose="/tmp/test-compose-$$.yml"
    cat > "$test_compose" << 'EOF'
version: '3.8'
services:
  test:
    image: alpine:latest
    command: echo "Docker Compose test successful"
EOF
    
    if ! docker compose -f "$test_compose" up --abort-on-container-exit >/dev/null 2>&1; then
        log_error "❌ Docker Compose functionality test failed"
        rm -f "$test_compose"
        return 1
    else
        log_info "✅ Docker Compose functionality working"
    fi
    
    # Cleanup
    docker compose -f "$test_compose" down >/dev/null 2>&1 || true
    rm -f "$test_compose"
    
    return 0
}

# Test network connectivity
test_network_connectivity() {
    log_info "Testing network connectivity..."
    
    # Test internet connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "❌ No internet connectivity"
        return 1
    else
        log_info "✅ Internet connectivity available"
    fi
    
    # Test Docker Hub connectivity
    if ! curl -s --connect-timeout 5 https://registry-1.docker.io/v2/ >/dev/null; then
        log_error "❌ Cannot reach Docker Hub"
        return 1
    else
        log_info "✅ Docker Hub connectivity available"
    fi
    
    # Test Grafana registry connectivity
    if ! curl -s --connect-timeout 5 https://grafana.com >/dev/null; then
        log_warn "⚠️  Cannot reach Grafana registry"
        log_warn "May affect plugin downloads"
    else
        log_info "✅ Grafana registry connectivity available"
    fi
    
    return 0
}

# Performance benchmark
run_performance_benchmark() {
    log_info "Running basic performance benchmark..."
    
    # CPU benchmark
    log_debug "Running CPU benchmark..."
    local cpu_start
    cpu_start=$(date +%s.%N)
    
    # Simple CPU test
    for i in {1..1000}; do
        echo "scale=100; 4*a(1)" | bc -l >/dev/null 2>&1 || break
    done
    
    local cpu_end
    cpu_end=$(date +%s.%N)
    local cpu_time
    cpu_time=$(echo "$cpu_end - $cpu_start" | bc)
    
    log_info "CPU Benchmark: ${cpu_time}s for 1000 calculations"
    
    # Memory benchmark
    log_debug "Running memory benchmark..."
    local mem_start
    mem_start=$(date +%s.%N)
    
    # Simple memory test
    dd if=/dev/zero of=/tmp/benchmark-$$ bs=1M count=100 >/dev/null 2>&1
    
    local mem_end
    mem_end=$(date +%s.%N)
    local mem_time
    mem_time=$(echo "$mem_end - $mem_start" | bc)
    
    log_info "Memory Benchmark: ${mem_time}s for 100MB write"
    
    # Cleanup
    rm -f /tmp/benchmark-$$
    
    # Disk I/O benchmark
    log_debug "Running disk I/O benchmark..."
    local io_start
    io_start=$(date +%s.%N)
    
    # Simple I/O test
    dd if=/dev/zero of="$PROJECT_ROOT/io-test-$$" bs=1M count=50 >/dev/null 2>&1
    sync
    
    local io_end
    io_end=$(date +%s.%N)
    local io_time
    io_time=$(echo "$io_end - $io_start" | bc)
    
    log_info "Disk I/O Benchmark: ${io_time}s for 50MB write"
    
    # Cleanup
    rm -f "$PROJECT_ROOT/io-test-$$"
    
    # Performance assessment
    if command_exists bc; then
        local cpu_score
        cpu_score=$(echo "scale=2; 10 / $cpu_time" | bc)
        local io_score
        io_score=$(echo "scale=2; 50 / $io_time" | bc)
        
        log_info "Performance Scores (higher is better):"
        log_info "  CPU Score: $cpu_score"
        log_info "  I/O Score: $io_score MB/s"
        
        # Performance recommendations
        if (( $(echo "$cpu_score < 1" | bc -l) )); then
            log_warn "⚠️  Low CPU performance - consider reducing service load"
        fi
        
        if (( $(echo "$io_score < 10" | bc -l) )); then
            log_warn "⚠️  Low I/O performance - consider using SSD storage"
        fi
    fi
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help        Show this help message"
            echo "  --benchmark       Run performance benchmark"
            echo "  --network-test    Test network connectivity only"
            echo "  --docker-test     Test Docker functionality only"
            echo ""
            echo "This script performs comprehensive system validation for PiMonitor."
            exit 0
            ;;
        --benchmark)
            show_banner
            run_performance_benchmark
            ;;
        --network-test)
            show_banner
            test_network_connectivity
            ;;
        --docker-test)
            show_banner
            test_docker_functionality
            ;;
        "")
            show_banner
            
            # Run comprehensive validation
            if validate_system; then
                log_info "🎉 System validation completed successfully!"
                log_info "Your system is ready for PiMonitor deployment."
                
                # Offer to run benchmark
                if confirm "Would you like to run a performance benchmark?" "n"; then
                    echo ""
                    run_performance_benchmark
                fi
                
                echo ""
                log_info "Next steps:"
                log_info "  1. Run './scripts/setup.sh' to install PiMonitor"
                log_info "  2. Or run './scripts/deploy.sh start' if already configured"
            else
                log_error "❌ System validation failed"
                log_error "Please address the issues above before proceeding"
                exit 1
            fi
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