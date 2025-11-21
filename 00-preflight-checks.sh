#!/usr/bin/env bash

# ==============================================================================
# Module 00: Pre-flight Checks
# Validates system requirements before installation
# ==============================================================================

set -o pipefail

LOGFILE="${LOGFILE:-$HOME/setup-error.log}"

# Source common functions if available
if [ -f "$(dirname "$0")/utility.sh" ]; then
    source "$(dirname "$0")/utility.sh"
else
    # Minimal fallback functions
    log_info() { echo -e "\033[1;34mINFO\033[0m: $1"; }
    log_critical() { echo -e "\033[1;35mCRITICAL\033[0m: $1" >&2; exit 1; }
    log_warning() { echo -e "\033[1;33mWARNING\033[0m: $1"; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

module_00_checks() {
    log_info "=== MODULE 00: Pre-flight Checks ==="
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_critical "Do not run this script as root. Run as normal user with sudo access."
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "Testing sudo access..."
        if ! sudo true; then
            log_critical "Sudo access required"
        fi
    fi
    
    # Check Internet connectivity
    log_info "Checking Internet connectivity..."
    if ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
        log_critical "No Internet connectivity detected"
    fi
    
    # Check disk space (need at least 10GB free)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 10485760 ]; then
        log_critical "Insufficient disk space. Need at least 10GB free on /"
    fi
    
    # Detect Fedora version
    if [ -f /etc/fedora-release ]; then
        local fedora_version=$(rpm -E %fedora)
        log_info "Detected Fedora $fedora_version"
        if [ "$fedora_version" -lt 39 ]; then
            log_warning "This script is optimized for Fedora 39+. You are running Fedora $fedora_version"
        fi
    else
        log_critical "This script is designed for Fedora only"
    fi
    
    # Detect NVIDIA GPU
    if lspci | grep -i nvidia >/dev/null 2>&1; then
        log_info "NVIDIA GPU detected"
        export HAS_NVIDIA=1
        echo "HAS_NVIDIA=1" > /tmp/setup-nvidia-flag
    else
        log_warning "No NVIDIA GPU detected. NVIDIA driver installation will be skipped."
        export HAS_NVIDIA=0
        echo "HAS_NVIDIA=0" > /tmp/setup-nvidia-flag
    fi
    
    # Check SELinux state
    if command_exists getenforce; then
        local selinux_status=$(getenforce)
        log_info "SELinux status: $selinux_status"
        
        if [ "$selinux_status" = "Enforcing" ]; then
            log_warning "SELinux is in Enforcing mode. This may cause issues with:"
            log_warning "  - Docker containers (consider: sudo setsebool -P container_manage_cgroup on)"
            log_warning "  - Kubernetes pods"
            log_warning "  - Libvirt/KVM"
            log_warning "If you encounter permission issues, check: sudo ausearch -m avc -ts recent"
        fi
    fi
    
    log_info "All pre-flight checks passed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_00_checks
fi
