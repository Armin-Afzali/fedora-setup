#!/usr/bin/env bash

# ==============================================================================
# Module 07: Networking Tools
# Network diagnostics, monitoring, and security utilities
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_07_networking() {
    log_info "=== MODULE 07: Networking Tools ==="
    
    install_if_missing \
        nmap \
        tcpdump \
        wireshark \
        mtr \
        iperf3 \
        socat \
        bind-utils \
        iproute \
        wireguard-tools \
        nftables \
        traceroute
    
    if ! groups $USER | grep -q wireshark; then
        sudo usermod -aG wireshark $USER 2>> "$LOGFILE" || log_error "Wireshark group add failed"
    fi
    
    log_info "Networking tools setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_07_networking
fi
