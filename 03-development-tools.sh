#!/usr/bin/env bash

# ==============================================================================
# Module 03: Development Tools
# Programming languages, build tools, and package managers
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_03_devtools() {
    log_info "=== MODULE 03: Development Tools ==="
    
    log_info "Installing build tools..."
    if ! dnf group list installed | grep -q "Development Tools"; then
        sudo dnf groupinstall -y "Development Tools" 2>> "$LOGFILE" || log_error "Development Tools install failed"
    fi
    
    install_if_missing \
        gcc \
        gcc-c++ \
        clang \
        make \
        cmake \
        automake \
        autoconf \
        libtool \
        pkg-config \
        openssl-devel \
        libffi-devel \
        bzip2-devel \
        readline-devel \
        sqlite-devel \
        xz-devel \
        zlib-devel
    
    # Python
    log_info "Setting up Python environment..."
    install_if_missing python3 python3-pip python3-devel python3-pipx
    
    # Ensure pipx path
    python3 -m pipx ensurepath 2>> "$LOGFILE" || true
    export PATH="$HOME/.local/bin:$PATH"
    
    if ! command_exists poetry; then
        pipx install poetry 2>> "$LOGFILE" || log_error "poetry install failed"
    fi
    
    # Node.js
    log_info "Setting up Node.js environment..."
    install_if_missing nodejs npm
    
    # pnpm via npm (recommended method)
    if ! command_exists pnpm; then
        npm install -g pnpm 2>> "$LOGFILE" || log_error "pnpm install failed"
    fi
    
    # Rust from package manager
    log_info "Setting up Rust environment..."
    install_if_missing rust cargo rust-src rust-analyzer
    
    # Go from package manager
    log_info "Setting up Go environment..."
    install_if_missing golang
    export PATH=$PATH:/usr/lib/golang/bin
    
    log_info "Development tools setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_03_devtools
fi
