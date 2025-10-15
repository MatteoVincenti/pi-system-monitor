#!/bin/bash
# Common utilities and functions for PiMonitor scripts
# This library provides logging, error handling, and utility functions

# Strict error handling
set -euo pipefail

# =============================================================================
# Constants and Configuration
# =============================================================================

# Script metadata
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly PID_DIR="${PROJECT_ROOT}/.pids"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Default log level (can be overridden by LOG_LEVEL environment variable)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# =============================================================================
# Logging Functions
# =============================================================================

# Get current timestamp in ISO 8601 format
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get log level name
get_log_level_name() {
    case "$1" in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO)  echo "INFO"  ;;
        $LOG_LEVEL_WARN)  echo "WARN"  ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        $LOG_LEVEL_FATAL) echo "FATAL" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Generic logging function
log_message() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    
    # Check if we should log this level
    if [[ $level -lt $LOG_LEVEL ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(get_timestamp)
    local level_name
    level_name=$(get_log_level_name "$level")
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Format: [TIMESTAMP] [LEVEL] [SCRIPT] MESSAGE
    local log_entry="[$timestamp] [$level_name] [$SCRIPT_NAME] $message"
    
    # Output to stderr with color (if terminal supports it)
    if [[ -t 2 ]]; then
        echo -e "${color}[$timestamp] [$level_name] [$SCRIPT_NAME]${NC} $message" >&2
    else
        echo "$log_entry" >&2
    fi
    
    # Also log to file
    echo "$log_entry" >> "$LOG_DIR/pimonitor.log"
}

# Specific logging functions
log_debug() {
    log_message $LOG_LEVEL_DEBUG "$PURPLE" "$@"
}

log_info() {
    log_message $LOG_LEVEL_INFO "$GREEN" "$@"
}

log_warn() {
    log_message $LOG_LEVEL_WARN "$YELLOW" "$@"
}

log_error() {
    log_message $LOG_LEVEL_ERROR "$RED" "$@"
}

log_fatal() {
    log_message $LOG_LEVEL_FATAL "$RED" "$@"
}

# =============================================================================
# Error Handling
# =============================================================================

# Global error handler
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="${3:-unknown}"
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Failed command: $command"
    
    # Call cleanup function if it exists
    if declare -f cleanup > /dev/null; then
        log_info "Running cleanup..."
        cleanup || log_warn "Cleanup failed"
    fi
    
    exit "$exit_code"
}

# Set up error trap
setup_error_handling() {
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
    trap 'log_info "Script interrupted by user"; exit 130' INT TERM
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Get OS information
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${NAME:-Unknown} ${VERSION:-Unknown}"
    else
        uname -s
    fi
}

# Get architecture
get_architecture() {
    uname -m
}

# Check if port is available
is_port_available() {
    local port="$1"
    ! netstat -tuln 2>/dev/null | grep -q ":$port "
}

# Wait for port to be available
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local interval="${4:-1}"
    
    log_info "Waiting for $host:$port to be available (timeout: ${timeout}s)"
    
    local count=0
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [[ $count -ge $timeout ]]; then
            log_error "Timeout waiting for $host:$port"
            return 1
        fi
        sleep "$interval"
        ((count += interval))
    done
    
    log_info "$host:$port is now available"
}

# Generate random string
generate_random_string() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Validate email address
validate_email() {
    local email="$1"
    [[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Validate URL
validate_url() {
    local url="$1"
    [[ $url =~ ^https?://[A-Za-z0-9.-]+([:/][A-Za-z0-9./_-]*)?$ ]]
}

# =============================================================================
# File Operations
# =============================================================================

# Create backup of file
backup_file() {
    local file="$1"
    local backup_dir="${2:-$PROJECT_ROOT/backups}"
    
    if [[ ! -f "$file" ]]; then
        log_warn "File $file does not exist, skipping backup"
        return 0
    fi
    
    mkdir -p "$backup_dir"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$backup_dir/$(basename "$file").backup.$timestamp"
    
    cp "$file" "$backup_file"
    log_info "Created backup: $backup_file"
}

# Safe file replacement
replace_file() {
    local source="$1"
    local target="$2"
    local backup="${3:-true}"
    
    if [[ "$backup" == "true" ]] && [[ -f "$target" ]]; then
        backup_file "$target"
    fi
    
    mv "$source" "$target"
    log_info "Replaced file: $target"
}

# =============================================================================
# Process Management
# =============================================================================

# Create PID file
create_pid_file() {
    local name="$1"
    local pid="${2:-$$}"
    
    mkdir -p "$PID_DIR"
    echo "$pid" > "$PID_DIR/$name.pid"
    log_debug "Created PID file for $name: $pid"
}

# Remove PID file
remove_pid_file() {
    local name="$1"
    local pid_file="$PID_DIR/$name.pid"
    
    if [[ -f "$pid_file" ]]; then
        rm -f "$pid_file"
        log_debug "Removed PID file for $name"
    fi
}

# Check if process is running
is_process_running() {
    local name="$1"
    local pid_file="$PID_DIR/$name.pid"
    
    if [[ ! -f "$pid_file" ]]; then
        return 1
    fi
    
    local pid
    pid=$(cat "$pid_file")
    kill -0 "$pid" 2>/dev/null
}

# =============================================================================
# User Interaction
# =============================================================================

# Prompt for yes/no confirmation
confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " -r response
            response=${response:-y}
        else
            read -p "$prompt [y/N]: " -r response
            response=${response:-n}
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Select from menu
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo "$prompt"
    for i in "${!options[@]}"; do
        echo "$((i + 1)). ${options[i]}"
    done
    
    while true; do
        read -p "Enter your choice (1-${#options[@]}): " -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
            echo "${options[$((choice - 1))]}"
            return 0
        else
            echo "Invalid choice. Please enter a number between 1 and ${#options[@]}."
        fi
    done
}

# =============================================================================
# System Information
# =============================================================================

# Get system load
get_system_load() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ','
}

# Get memory usage percentage
get_memory_usage() {
    free | awk 'NR==2{printf "%.2f", $3*100/$2}'
}

# Get disk usage percentage
get_disk_usage() {
    local path="${1:-/}"
    df "$path" | awk 'NR==2{print $5}' | tr -d '%'
}

# =============================================================================
# Initialization
# =============================================================================

# Initialize common library
init_common() {
    # Set up error handling
    setup_error_handling
    
    # Create necessary directories
    mkdir -p "$LOG_DIR" "$PID_DIR"
    
    # Log script start
    log_info "Starting $SCRIPT_NAME (PID: $$)"
    log_debug "Project root: $PROJECT_ROOT"
    log_debug "OS: $(get_os_info)"
    log_debug "Architecture: $(get_architecture)"
}

# Cleanup function (can be overridden by scripts)
cleanup() {
    log_info "Performing cleanup..."
    # Remove PID file if it exists
    remove_pid_file "$SCRIPT_NAME"
}

# Auto-initialize if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_common
fi