#!/bin/bash

#############################################
# Fedora 43 Setup - Networking Tools
# Description: Network analysis, debugging, VPN, proxies, service mesh
# Author: DevOps Setup Script
# Date: 2025
#############################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_DIR="${HOME}/.fedora-setup-logs"
LOG_FILE="${LOG_DIR}/06-networking-tools-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

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

error_exit() {
    print_error "$1"
    exit 1
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should NOT be run as root. Run as normal user with sudo privileges."
    fi
}

check_sudo() {
    if ! sudo -v; then
        error_exit "Sudo privileges required but not available"
    fi
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
}

# Install network analysis tools
install_network_analysis() {
    print_header "Installing Network Analysis and Debugging Tools"
    
    local packages=(
        wireshark
        wireshark-cli
        tcpdump
        nmap
        nmap-ncat
        netcat
        socat
        iperf3
        iftop
        mtr
        ethtool
        iproute
        net-tools
        bridge-utils
        traceroute
        whois
        bind-utils
        NetworkManager
        NetworkManager-tui
        bmon
        vnstat
        nethogs
        iptraf-ng
        tcpflow
        tcpreplay
        hping3
        ipcalc
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Add user to wireshark group for packet capture
    print_info "Adding user to wireshark group..."
    sudo usermod -aG wireshark "${USER}" 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Network analysis tools installed"
}

# Install DNS and service discovery tools
install_dns_tools() {
    print_header "Installing DNS and Service Discovery Tools"
    
    local packages=(
        dnsmasq
        unbound
        bind
        bind-utils
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install etcd
    if ! command -v etcd &>/dev/null; then
        print_info "Installing etcd..."
        sudo dnf5 install -y etcd 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install etcd"
    fi
    
    # Install consul
    if ! command -v consul &>/dev/null; then
        print_info "Installing Consul..."
        if [[ ! -f /etc/yum.repos.d/hashicorp.repo ]]; then
            sudo dnf5 config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>&1 | tee -a "${LOG_FILE}"
        fi
        sudo dnf5 install -y consul 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install consul"
    fi
    
    print_success "DNS and service discovery tools installed"
}

# Install load balancers and proxies
install_proxies() {
    print_header "Installing Load Balancers and Proxies"
    
    local packages=(
        haproxy
        nginx
        squid
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install Envoy
    if ! command -v envoy &>/dev/null; then
        print_info "Installing Envoy..."
        # Envoy is best installed via getenvoy or container
        print_warning "Envoy requires manual installation or use container image"
        print_info "Visit: https://www.getenvoy.io/ or use: docker pull envoyproxy/envoy"
    fi
    
    # Install Traefik
    if ! command -v traefik &>/dev/null; then
        print_info "Installing Traefik..."
        local version=$(curl -s https://api.github.com/repos/traefik/traefik/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/traefik/traefik/releases/download/${version}/traefik_${version}_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin traefik 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/traefik
        print_success "Traefik installed"
    else
        print_info "Traefik already installed"
    fi
    
    # Install Caddy
    if ! command -v caddy &>/dev/null; then
        print_info "Installing Caddy..."
        sudo dnf5 copr enable @caddy/caddy -y 2>&1 | tee -a "${LOG_FILE}"
        sudo dnf5 install -y caddy 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Caddy"
    fi
    
    print_success "Load balancers and proxies installed"
}

# Install VPN and tunneling tools
install_vpn_tools() {
    print_header "Installing VPN and Tunneling Tools"
    
    local packages=(
        wireguard-tools
        openvpn
        strongswan
        openssh
        autossh
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install sshuttle
    if ! command -v sshuttle &>/dev/null; then
        print_info "Installing sshuttle..."
        pip3 install --user sshuttle 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install sshuttle"
    fi
    
    # Install Tailscale
    if ! command -v tailscale &>/dev/null; then
        print_info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Tailscale"
    fi
    
    # Install cloudflared
    if ! command -v cloudflared &>/dev/null; then
        print_info "Installing cloudflared..."
        cd /tmp
        local cf_version=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L "https://github.com/cloudflare/cloudflared/releases/download/${cf_version}/cloudflared-linux-amd64.rpm" -o cloudflared.rpm 2>&1 | tee -a "${LOG_FILE}"
        sudo dnf5 install -y ./cloudflared.rpm 2>&1 | tee -a "${LOG_FILE}"
        rm cloudflared.rpm
        print_success "cloudflared installed"
    else
        print_info "cloudflared already installed"
    fi
    
    print_success "VPN and tunneling tools installed"
}

# Install network security tools
install_network_security() {
    print_header "Installing Network Security Tools"
    
    local packages=(
        iptables
        iptables-services
        nftables
        firewalld
        fail2ban
        ufw
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Enable firewalld by default
    print_info "Enabling firewalld..."
    sudo systemctl enable --now firewalld 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Network security tools installed"
}

# Install service mesh tools
install_service_mesh() {
    print_header "Installing Service Mesh Tools"
    
    # Install Istio
    if ! command -v istioctl &>/dev/null; then
        print_info "Installing Istio..."
        curl -L https://istio.io/downloadIstio | sh - 2>&1 | tee -a "${LOG_FILE}"
        
        # Find the istioctl binary and move to /usr/local/bin
        local istio_dir=$(find . -maxdepth 1 -type d -name "istio-*" | head -1)
        if [[ -n "$istio_dir" && -f "${istio_dir}/bin/istioctl" ]]; then
            sudo cp "${istio_dir}/bin/istioctl" /usr/local/bin/
            rm -rf "$istio_dir"
            print_success "Istio installed"
        else
            print_warning "Istio installation incomplete"
        fi
    else
        print_info "Istio already installed"
    fi
    
    # Install Linkerd
    if ! command -v linkerd &>/dev/null; then
        print_info "Installing Linkerd..."
        curl -fsL https://run.linkerd.io/install | sh 2>&1 | tee -a "${LOG_FILE}"
        export PATH="$HOME/.linkerd2/bin:$PATH"
        print_success "Linkerd installed"
        print_info "Add to your shell rc: export PATH=\"\$HOME/.linkerd2/bin:\$PATH\""
    else
        print_info "Linkerd already installed"
    fi
}

# Install bandwidth monitoring tools
install_bandwidth_tools() {
    print_header "Installing Bandwidth Monitoring Tools"
    
    # bandwhich (modern bandwidth monitor)
    if ! command -v bandwhich &>/dev/null; then
        print_info "Installing bandwhich..."
        local version=$(curl -s https://api.github.com/repos/imsnif/bandwhich/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L "https://github.com/imsnif/bandwhich/releases/download/${version}/bandwhich-${version}-x86_64-unknown-linux-musl.tar.gz" | sudo tar xz -C /usr/local/bin 2>&1 | tee -a "${LOG_FILE}"
        print_success "bandwhich installed"
    else
        print_info "bandwhich already installed"
    fi
    
    # dog (DNS client)
    if ! command -v dog &>/dev/null; then
        print_info "Installing dog..."
        local version=$(curl -s https://api.github.com/repos/ogham/dog/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L "https://github.com/ogham/dog/releases/download/${version}/dog-${version}-x86_64-unknown-linux-gnu.zip" -o /tmp/dog.zip 2>&1 | tee -a "${LOG_FILE}"
        sudo unzip -o /tmp/dog.zip -d /usr/local/bin/ bin/dog 2>&1 | tee -a "${LOG_FILE}"
        sudo mv /usr/local/bin/bin/dog /usr/local/bin/
        sudo rmdir /usr/local/bin/bin 2>/dev/null || true
        rm /tmp/dog.zip
        print_success "dog installed"
    else
        print_info "dog already installed"
    fi
}

# Main execution
main() {
    print_header "Fedora 43 Networking Tools Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    install_network_analysis
    install_dns_tools
    install_proxies
    install_vpn_tools
    install_network_security
    install_bandwidth_tools
    
    # Ask about service mesh (heavy installation)
    read -p "Install Service Mesh tools (Istio, Linkerd)? (y/n) " -n 1 -r install_mesh
    echo
    [[ $install_mesh =~ ^[Yy]$ ]] && install_service_mesh
    
    print_header "Installation Summary"
    print_success "Networking Tools setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    echo "  - Network analysis: wireshark, tcpdump, nmap, mtr"
    echo "  - DNS: dnsmasq, unbound, consul, etcd"
    echo "  - Proxies: haproxy, nginx, traefik, caddy"
    echo "  - VPN: wireguard, openvpn, tailscale, cloudflared"
    echo "  - Security: firewalld, fail2ban"
    echo "  - Monitoring: iftop, nethogs, bandwhich"
    [[ $install_mesh =~ ^[Yy]$ ]] && echo "  - Service Mesh: istio, linkerd"
    
    print_info "\nNext Steps:"
    echo "1. Log out and back in for group memberships to take effect"
    echo "2. Test Wireshark packet capture capabilities"
    echo "3. Configure firewalld: sudo firewall-cmd --list-all"
    echo "4. Setup Tailscale: sudo tailscale up"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
