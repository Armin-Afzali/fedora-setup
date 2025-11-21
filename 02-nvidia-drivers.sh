#!/usr/bin/env bash

# ==============================================================================
# Module 02: NVIDIA Drivers
# NVIDIA proprietary driver installation and configuration
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_02_nvidia() {
    if [ "$HAS_NVIDIA" -ne 1 ]; then
        log_info "=== MODULE 02: NVIDIA (Skipped - No GPU detected) ==="
        return 0
    fi
    
    log_info "=== MODULE 02: NVIDIA Drivers ==="
    
    log_info "Installing NVIDIA drivers..."
    install_if_missing \
        akmod-nvidia \
        xorg-x11-drv-nvidia \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-cuda-libs \
        xorg-x11-drv-nvidia-libs \
        vdpauinfo \
        libva-utils \
        vulkan
    
    log_info "Configuring NVIDIA kernel parameters..."
    if ! sudo grubby --info=ALL 2>/dev/null | grep -q "nvidia-drm.modeset=1"; then
        sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1" 2>> "$LOGFILE" || \
            log_error "Failed to update kernel parameters"
    fi
    
    log_info "Building NVIDIA kernel modules..."
    sudo akmods --force 2>> "$LOGFILE" || log_warning "akmods force build had issues"
    sudo dracut -f 2>> "$LOGFILE" || log_warning "dracut rebuild had issues"
    
    log_info "NVIDIA driver installation complete. Validation will occur after reboot."
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_02_nvidia
fi
