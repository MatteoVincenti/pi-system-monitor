#!/bin/bash

# PiMonitor Branding Library
# Provides ASCII art branding and visual enhancement functions

# Configuration
PIMONITOR_VERSION="2.0.0"
PIMONITOR_ASCII_ART="${PIMONITOR_ASCII_ART:-true}"
PIMONITOR_COLOR_OUTPUT="${PIMONITOR_COLOR_OUTPUT:-true}"

# Color definitions (only set if not already defined)
if [[ -z "${RED:-}" ]]; then
    if [[ "$PIMONITOR_COLOR_OUTPUT" == "true" ]] && [[ -t 1 ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        PURPLE='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[1;37m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        PURPLE=''
        CYAN=''
        WHITE=''
        BOLD=''
        NC=''
    fi
fi

# ASCII Art Assets
show_pimonitor_logo() {
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${CYAN:-}"
        cat << 'EOF'
   ____  _ __  __            _ __           
  / __ \(_) /_/ /_____  ____(_) /_____  ____
 / /_/ / / __/ __/ __ \/ ___/ / __/ __ \/ ___/
/ ____/ / /_/ /_/ /_/ / /  / / /_/ /_/ / /    
/_/   /_/\__/\__/\____/_/  /_/\__/\____/_/     
EOF
        echo -e "${NC:-}"
        echo -e "${WHITE:-}${BOLD:-}PiMonitor v${PIMONITOR_VERSION}${NC:-}"
        echo -e "${BLUE:-}Docker-based observability stack for Raspberry Pi${NC:-}"
        echo
    else
        echo "PiMonitor v${PIMONITOR_VERSION}"
        echo "Docker-based observability stack for Raspberry Pi"
        echo
    fi
}

# Compact header for submenus
show_compact_header() {
    local title="$1"
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${CYAN:-}╔══════════════════════════════════════════════════╗${NC:-}"
        echo -e "${CYAN:-}║${NC:-} ${WHITE:-}${BOLD:-}PiMonitor${NC:-} ${CYAN:-}║${NC:-} ${title}"
        echo -e "${CYAN:-}╚══════════════════════════════════════════════════╝${NC:-}"
        echo
    else
        echo "=== PiMonitor - ${title} ==="
        echo
    fi
}

# Status indicators
show_success() {
    local message="$1"
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${GREEN:-}✓${NC:-} ${message}"
    else
        echo "[SUCCESS] ${message}"
    fi
}

show_error() {
    local message="$1"
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${RED:-}✗${NC:-} ${message}"
    else
        echo "[ERROR] ${message}"
    fi
}

show_warning() {
    local message="$1"
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${YELLOW:-}⚠${NC:-} ${message}"
    else
        echo "[WARNING] ${message}"
    fi
}

show_info() {
    local message="$1"
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${BLUE:-}ℹ${NC:-} ${message}"
    else
        echo "[INFO] ${message}"
    fi
}

# Progress indicators
show_progress() {
    local message="$1"
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${PURPLE:-}⟳${NC:-} ${message}..."
    else
        echo "[PROGRESS] ${message}..."
    fi
}

# Menu separators
show_separator() {
    if [[ "$PIMONITOR_ASCII_ART" == "true" ]]; then
        echo -e "${CYAN:-}────────────────────────────────────────────────────${NC:-}"
    else
        echo "----------------------------------------------------"
    fi
}

# Terminal compatibility check
check_terminal_support() {
    local width=$(tput cols 2>/dev/null || echo 80)
    local height=$(tput lines 2>/dev/null || echo 24)
    
    # Disable ASCII art if terminal is too narrow
    if [[ $width -lt 60 ]]; then
        PIMONITOR_ASCII_ART="false"
        show_warning "Terminal too narrow for ASCII art, using text mode"
    fi
    
    # Check for color support
    if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]]; then
        PIMONITOR_COLOR_OUTPUT="false"
    fi
}

# Initialize branding system
init_branding() {
    check_terminal_support
}

# Export functions for use in other scripts
export -f show_pimonitor_logo
export -f show_compact_header
export -f show_success
export -f show_error
export -f show_warning
export -f show_info
export -f show_progress
export -f show_separator
export -f check_terminal_support
export -f init_branding