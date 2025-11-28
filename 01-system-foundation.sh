#!/bin/bash

#############################################
# Fedora 43 Setup - System Foundation
# Description: NVIDIA drivers, core graphics, system utilities
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

    # Add NVIDIA Container Toolkit repo first (for GPU containers)
    if [ ! -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]; then
        print_info "Adding NVIDIA Container Toolkit repo..."
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    fi

    if [ ! -f /etc/yum.repos.d/cuda-fedora42.repo ]; then
        print_info "Adding NVIDIA CUDA repo for cuDNN..."
        sudo dnf5 config-manager addrepo --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora42/$(uname -m)/cuda-fedora42.repo
        sudo dnf config-manager setopt cuda-fedora42-$(uname -m).exclude=nvidia-driver,nvidia-modprobe,nvidia-persistenced,nvidia-settings,nvidia-libXNVCtrl,nvidia-xconfig
    fi
    
    local packages=(
        akmod-nvidia
        cuda-toolkit xorg-x11-drv-nvidia-cuda
        nvidia-settings
        libva-nvidia-driver
        vulkan vulkan-loader vulkan-tools
        libva-utils vdpauinfo
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

    # if ! rpm -q nvidia-container-toolkit &>/dev/null; then
    #     print_info "Installing NVIDIA Container Toolkit"
        
    #     # Install with version pinning
    #     print_info "Installing versioned NVIDIA Container Toolkit packages..."
    #     sudo dnf5 install -y --nogpgcheck \
    #         "nvidia-container-toolkit" \
    #         "nvidia-container-toolkit-base" \
    #         "libnvidia-container-tools" \
    #         "libnvidia-container1" \
    #         2>&1 | tee -a "${LOG_FILE}"
        
    #     print_success "NVIDIA Container Toolkit installed"
    # else
    #     print_info "NVIDIA Container Toolkit already installed"
    # fi

    # print_info "Configuring NVIDIA Container Toolkit for running containers"

    # if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    #     # Docker is installed and active → configure for Docker
    #     print_info "Docker detected → configuring NVIDIA runtime for Docker"
    #     sudo nvidia-ctk runtime configure --runtime=docker
    #     sudo systemctl restart docker
    #     print_success "NVIDIA runtime configured for Docker"

    # elif systemctl is-active --quiet containerd; then
    #     # containerd is running (default for Podman on Fedora)
    #     print_info "containerd detected (Podman) → configuring NVIDIA runtime"
    #     sudo nvidia-ctk runtime configure --runtime=containerd
    #     sudo systemctl restart containerd
    #     print_success "NVIDIA runtime configured for Podman/containerd"

    # else
    #     print_warning "Neither Docker nor containerd service found – skipping runtime configuration"
    #     print_info "You can manually run one of these later:"
    #     echo "   sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
    #     echo "   sudo nvidia-ctk runtime configure --runtime=containerd && sudo systemctl restart containerd"
    # fi
   
    # Optional cuDNN/CUDA (uncomment if AI/ML needed)
    if ! rpm -q cuda-cudnn &>/dev/null; then
        print_info "Installing cuDNN (AI/ML accel)..."
        sudo dnf5 install -y cuda-cudnn 2>&1 | tee -a "${LOG_FILE}" || print_warning "cuDNN failed (repo may need refresh)"
    fi
   
    # Full CUDA tools if repo added
    sudo dnf5 install -y cuda 2>&1 | tee -a "${LOG_FILE}" || true
    
    print_success "NVIDIA drivers installation completed"
    print_warning "Reboot required for NVIDIA drivers to take effect"

    if [ -d /sys/firmware/efi ] && mokutil --sb-state 2>/dev/null | grep -q "enabled"; then
        print_warning "Secure Boot detected – expect MOK enrollment screen on first reboot"
    fi
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
        gwe
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
    
    local settings=(
        "max_parallel_downloads=20"
        "fastestmirror=True"
        "deltarpm=True"
        "skip_if_unavailable=True"
        "keepcache=True"
        "install_weak_deps=False"
    )
   
    for setting in "${settings[@]}"; do
        local key="${setting%%=*}"
        if ! sudo grep -q "^${key}=" "$dnf_conf"; then
            echo "$setting" | sudo tee -a "$dnf_conf" > /dev/null
            print_info "Added $setting"
        fi
    done
   
    # Enable fastestmirror plugin explicitly
    sudo dnf5 install -y dnf-plugins-core 2>/dev/null || true
    
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
