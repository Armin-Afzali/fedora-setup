#!/usr/bin/env bash

# ==============================================================================
# Module 04: Cloud Provider CLIs
# Docker, cloud provider tools, and remote access utilities
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_04_cloud() {
    log_info "=== MODULE 04: Cloud Provider CLIs ==="
    
    # Docker
    log_info "Installing Docker..."
    if ! package_installed docker-ce; then
        if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
            sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>> "$LOGFILE" || \
                log_critical "Docker repo add failed"
        fi
        
        install_critical \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin
        
        sudo systemctl enable --now docker 2>> "$LOGFILE" || log_critical "Docker enable failed"
        
        if ! groups $USER | grep -q docker; then
            sudo usermod -aG docker $USER 2>> "$LOGFILE" || log_error "Docker group add failed"
        fi
    fi
    
    # NVIDIA Container Toolkit
    if [ "$HAS_NVIDIA" -eq 1 ]; then
        log_info "Installing NVIDIA Container Toolkit..."
        if ! package_installed nvidia-container-toolkit; then
            if [ ! -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]; then
                curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
                    sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo >/dev/null 2>> "$LOGFILE"
            fi
            
            install_if_missing nvidia-container-toolkit
            sudo nvidia-ctk runtime configure --runtime=docker 2>> "$LOGFILE" || log_error "NVIDIA runtime config failed"
            sudo systemctl restart docker 2>> "$LOGFILE" || log_error "Docker restart failed"
        fi
    fi
    
    # AWS CLI v2 (no package manager option, must use installer)
    log_info "Installing AWS CLI v2..."
    if ! command_exists aws; then
        local aws_zip="$TMP_DIR/awscliv2.zip"
        if safe_download "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "$aws_zip"; then
            unzip -q "$aws_zip" -d "$TMP_DIR" 2>> "$LOGFILE" || true
            sudo "$TMP_DIR/aws/install" --update 2>> "$LOGFILE" || log_error "AWS CLI install failed"
        fi
    fi
    
    # Azure CLI
    log_info "Installing Azure CLI..."
    if ! command_exists az; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>> "$LOGFILE" || true
        
        if [ ! -f /etc/yum.repos.d/azure-cli.repo ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/azure-cli.repo
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        fi
        
        install_if_missing azure-cli
    fi
    
    # Google Cloud CLI
    log_info "Installing Google Cloud CLI..."
    if ! command_exists gcloud; then
        if [ ! -f /etc/yum.repos.d/google-cloud-sdk.repo ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/google-cloud-sdk.repo
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
        fi
        
        install_if_missing google-cloud-cli
    fi
    
    # GitHub CLI
    log_info "Installing GitHub CLI..."
    install_if_missing gh
    
    # Tailscale
    log_info "Installing Tailscale..."
    if ! command_exists tailscale; then
        if [ ! -f /etc/yum.repos.d/tailscale.repo ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/tailscale.repo
[tailscale-stable]
name=Tailscale stable
baseurl=https://pkgs.tailscale.com/stable/fedora/\$basearch
enabled=1
type=rpm
repo_gpgcheck=1
gpgcheck=0
gpgkey=https://pkgs.tailscale.com/stable/fedora/repo.gpg
EOF
        fi
        
        install_if_missing tailscale
        sudo systemctl enable --now tailscaled 2>> "$LOGFILE" || log_error "Tailscale enable failed"
    fi
    
    log_info "Cloud tools setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_04_cloud
fi
