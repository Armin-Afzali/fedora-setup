#!/usr/bin/env bash

# ==============================================================================
# Module 06: Infrastructure as Code & Configuration Management
# Terraform, Ansible, Vault, chezmoi, age
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_06_iac() {
    log_info "=== MODULE 06: IaC & Configuration Management ==="
    
    # HashiCorp repo
    if ! package_installed terraform; then
        if [ ! -f /etc/yum.repos.d/hashicorp.repo ]; then
            sudo dnf-3 config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>> "$LOGFILE" || \
                log_error "HashiCorp repo add failed"
        fi
    fi
    
    # Terraform
    log_info "Installing Terraform..."
    install_critical terraform
    
    # Vault
    log_info "Installing Vault CLI..."
    install_if_missing vault
    
    # Ansible
    log_info "Installing Ansible..."
    install_if_missing ansible ansible-core
    
    # chezmoi from package manager
    log_info "Installing chezmoi..."
    install_if_missing chezmoi
    
    # age from COPR (if available) or manual install
    log_info "Installing age..."
    if ! command_exists age; then
        # Try COPR first
        if ! package_installed age; then
            sudo dnf copr enable -y @go-sig/age 2>> "$LOGFILE" || true
            install_if_missing age || {
                # Fallback to manual install if COPR fails
                local AGE_VERSION="1.2.0"
                local age_tarball="$TMP_DIR/age.tar.gz"
                if safe_download "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" "$age_tarball"; then
                    tar -xzf "$age_tarball" -C "$TMP_DIR" 2>> "$LOGFILE" || true
                    sudo install -o root -g root -m 0755 "$TMP_DIR/age/age" /usr/local/bin/age 2>> "$LOGFILE"
                    sudo install -o root -g root -m 0755 "$TMP_DIR/age/age-keygen" /usr/local/bin/age-keygen 2>> "$LOGFILE"
                fi
            }
        fi
    fi
    
    log_info "IaC tools setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_06_iac
fi
