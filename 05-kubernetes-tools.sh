#!/usr/bin/env bash

# ==============================================================================
# Module 05: Kubernetes Tools
# kubectl, k9s, kind, helm, krew, stern, and related utilities
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_05_kubernetes() {
    log_info "=== MODULE 05: Kubernetes Tools ==="
    
    # kubectl
    log_info "Installing kubectl..."
    if ! command_exists kubectl; then
        if [ ! -f /etc/yum.repos.d/kubernetes.repo ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF
        fi
        
        install_critical kubectl
    fi
    
    # k9s
    log_info "Installing k9s..."
    if ! command_exists k9s; then
        local K9S_VERSION="v0.32.5"
        local k9s_tarball="$TMP_DIR/k9s.tar.gz"
        if safe_download "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" "$k9s_tarball"; then
            tar -xzf "$k9s_tarball" -C "$TMP_DIR" 2>> "$LOGFILE" || true
            sudo install -o root -g root -m 0755 "$TMP_DIR/k9s" /usr/local/bin/k9s 2>> "$LOGFILE" || log_error "k9s install failed"
        fi
    fi
    
    # kind
    log_info "Installing kind..."
    if ! command_exists kind; then
        local KIND_VERSION="v0.24.0"
        local kind_binary="$TMP_DIR/kind"
        if safe_download "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" "$kind_binary"; then
            sudo install -o root -g root -m 0755 "$kind_binary" /usr/local/bin/kind 2>> "$LOGFILE" || log_error "kind install failed"
        fi
    fi
    
    # krew (kubectl plugin manager)
    log_info "Installing krew..."
    if [ ! -d "$HOME/.krew" ]; then
        local krew_tarball="$TMP_DIR/krew.tar.gz"
        if safe_download "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_amd64.tar.gz" "$krew_tarball"; then
            tar -xzf "$krew_tarball" -C "$TMP_DIR" 2>> "$LOGFILE" || true
            "$TMP_DIR/krew-linux_amd64" install krew 2>> "$LOGFILE" || log_error "krew install failed"
        fi
    fi
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
    
    # stern
    log_info "Installing stern..."
    if ! command_exists stern; then
        local STERN_VERSION="1.30.0"
        local stern_tarball="$TMP_DIR/stern.tar.gz"
        if safe_download "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz" "$stern_tarball"; then
            tar -xzf "$stern_tarball" -C "$TMP_DIR" 2>> "$LOGFILE" || true
            sudo install -o root -g root -m 0755 "$TMP_DIR/stern" /usr/local/bin/stern 2>> "$LOGFILE" || log_error "stern install failed"
        fi
    fi
    
    # Helm
    log_info "Installing Helm..."
    install_if_missing helm
    
    log_info "Kubernetes tools setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_05_kubernetes
fi
