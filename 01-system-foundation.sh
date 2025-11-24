#!/bin/bash

#############################################
# Fedora 43 Setup - System Foundation
# Description: NVIDIA drivers, core graphics, system utilities
# Author: DevOps Setup Script
# Date: 2025
#############################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging setup
LOG_DIR="${HOME}/.fedora-setup-logs"
LOG_FILE="${LOG_DIR}/01-system-foundation-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

# Log function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Pretty print functions
print_header() {
    echo -e "\n${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}\n"
    log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING" "$1"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO" "$1"
}

# Error handler
error_exit() {
    print_error "$1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should NOT be run as root. Run as normal user with sudo privileges."
    fi
}

# Check sudo access
check_sudo() {
    if ! sudo -v; then
        error_exit "Sudo privileges required but not available"
    fi
    # Keep sudo alive
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
}

# Detect NVIDIA GPU
detect_nvidia() {
    if lspci | grep -i nvidia &>/dev/null; then
        print_success "NVIDIA GPU detected"
        return 0
    else
        print_warning "No NVIDIA GPU detected. Skipping NVIDIA driver installation."
        return 1
    fi
}

# Enable RPM Fusion repositories
enable_rpm_fusion() {
    print_header "Enabling RPM Fusion Repositories"
    
    if ! dnf5 repolist | grep -q "rpmfusion"; then
        print_info "Installing RPM Fusion repositories..."
        sudo dnf5 install -y \
            https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
            2>&1 | tee -a "${LOG_FILE}"
        print_success "RPM Fusion repositories enabled"
    else
        print_info "RPM Fusion already enabled"
    fi
}

# Install NVIDIA drivers
install_nvidia() {
    if ! detect_nvidia; then
        return 0
    fi
    
    print_header "Installing NVIDIA Drivers and Tools"
    
    local packages=(
        akmod-nvidia
        xorg-x11-drv-nvidia-cuda
        nvidia-settings
        nvidia-vaapi-driver
        libva-utils
        vdpauinfo
        vulkan
        vulkan-loader
        vulkan-tools
    )
    
    print_info "Installing NVIDIA packages..."
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "NVIDIA drivers installation completed"
    print_warning "Reboot required for NVIDIA drivers to take effect"
}

# Install system utilities
install_system_utilities() {
    print_header "Installing System Utilities and Performance Tools"
    
    local packages=(
        dnf-plugins-core
        htop
        btop
        glances
        powertop
        tlp
        tlp-rdw
        tuned
        numactl
        stress
        stress-ng
        lm_sensors
        smartmontools
        nvme-cli
        util-linux
        sysstat
        procps-ng
    )
    
    print_info "Installing system utilities..."
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "System utilities installed"
}

# Configure DNF
configure_dnf() {
    print_header "Configuring DNF for Better Performance"
    
    local dnf_conf="/etc/dnf/dnf.conf"
    
    print_info "Backing up DNF configuration..."
    sudo cp "$dnf_conf" "${dnf_conf}.backup.$(date +%Y%m%d)" || true
    
    print_info "Adding DNF optimizations..."
    
    # Add configurations if not present
    sudo grep -q "^max_parallel_downloads=" "$dnf_conf" || echo "max_parallel_downloads=10" | sudo tee -a "$dnf_conf"
    sudo grep -q "^fastestmirror=" "$dnf_conf" || echo "fastestmirror=True" | sudo tee -a "$dnf_conf"
    sudo grep -q "^deltarpm=" "$dnf_conf" || echo "deltarpm=True" | sudo tee -a "$dnf_conf"
    
    print_success "DNF configuration optimized"
}

# Enable and start services
configure_services() {
    print_header "Configuring System Services"
    
    # TLP for power management
    if systemctl list-unit-files | grep -q tlp.service; then
        print_info "Enabling TLP service..."
        sudo systemctl enable --now tlp.service 2>&1 | tee -a "${LOG_FILE}"
        print_success "TLP service enabled"
    fi
    
    # Tuned for system performance
    if systemctl list-unit-files | grep -q tuned.service; then
        print_info "Enabling tuned service..."
        sudo systemctl enable --now tuned.service 2>&1 | tee -a "${LOG_FILE}"
        print_success "Tuned service enabled"
    fi
    
    # SMART monitoring
    if systemctl list-unit-files | grep -q smartd.service; then
        print_info "Enabling smartd service..."
        sudo systemctl enable --now smartd.service 2>&1 | tee -a "${LOG_FILE}"
        print_success "Smartd service enabled"
    fi
}

# System update
update_system() {
    print_header "Updating System"
    
    print_info "Running system update..."
    sudo dnf5 upgrade -y 2>&1 | tee -a "${LOG_FILE}"
    print_success "System updated"
}

# Main execution
main() {
    print_header "Fedora 43 System Foundation Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    configure_dnf
    update_system
    enable_rpm_fusion
    install_nvidia
    install_system_utilities
    configure_services
    
    print_header "Installation Summary"
    print_success "System foundation setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    if detect_nvidia; then
        print_warning "NVIDIA drivers installed. Please reboot your system for changes to take effect."
        print_info "After reboot, verify installation with: nvidia-smi"
    fi
    
    print_info "Review the log file for any warnings or errors"
}

# Run main function
main "$@"
