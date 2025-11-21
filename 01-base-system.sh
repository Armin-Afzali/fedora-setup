#!/usr/bin/env bash

# ==============================================================================
# Module 01: Base System Setup
# System upgrades, repositories, security, and essential utilities
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_01_base() {
    log_info "=== MODULE 01: Base System Setup ==="
    
    log_info "Upgrading system packages..."
    sudo dnf upgrade -y --refresh 2>> "$LOGFILE" || log_error "System upgrade had issues"
    
    log_info "Installing RPM Fusion repositories..."
    if ! package_installed rpmfusion-free-release; then
        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            2>> "$LOGFILE" || log_error "RPM Fusion Free install failed"
    fi
    
    if ! package_installed rpmfusion-nonfree-release; then
        sudo dnf install -y \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
            2>> "$LOGFILE" || log_error "RPM Fusion Nonfree install failed"
    fi
    
    sudo dnf upgrade -y --refresh 2>> "$LOGFILE" || log_error "Post-RPM Fusion upgrade had issues"
    
    log_info "Configuring FirewallD..."
    install_critical firewalld
    sudo systemctl enable --now firewalld 2>> "$LOGFILE" || log_critical "FirewallD enable failed"
    sudo firewall-cmd --permanent --add-service=ssh 2>> "$LOGFILE" || true
    sudo firewall-cmd --reload 2>> "$LOGFILE" || true
    
    log_info "Installing and configuring Fail2ban..."
    install_if_missing fail2ban fail2ban-firewalld
    sudo systemctl enable --now fail2ban 2>> "$LOGFILE" || log_error "Fail2ban enable failed"
    
    log_info "Installing essential utilities..."
    install_if_missing \
        vim \
        neovim \
        git \
        git-lfs \
        curl \
        wget \
        unzip \
        zip \
        p7zip \
        p7zip-plugins \
        rsync \
        screen \
        jq \
        yq \
        tree \
        ncdu \
        htop
    
    git lfs install 2>> "$LOGFILE" || true
    
    log_info "Base system setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_01_base
fi
