#!/bin/bash

#############################################
# Fedora 43 Setup - Security & Secrets Management
# Description: Vault, secrets tools, security scanning, certificates
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
LOG_FILE="${LOG_DIR}/09-security-secrets-$(date +%Y%m%d-%H%M%S).log"
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

# Install HashiCorp Vault
install_vault() {
    print_header "Installing HashiCorp Vault"
    
    if ! command -v vault &>/dev/null; then
        print_info "Installing Vault from HashiCorp repository..."
        
        if [[ ! -f /etc/yum.repos.d/hashicorp.repo ]]; then
            sudo dnf5 config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>&1 | tee -a "${LOG_FILE}"
        fi
        
        sudo dnf5 install -y vault 2>&1 | tee -a "${LOG_FILE}"
        print_success "Vault installed: $(vault version)"
    else
        print_info "Vault already installed"
    fi
}

# Install SOPS
install_sops() {
    print_header "Installing SOPS"
    
    if ! command -v sops &>/dev/null; then
        print_info "Installing SOPS..."
        local version=$(curl -s https://api.github.com/repos/getsops/sops/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        sudo curl -L "https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.linux.amd64" -o /usr/local/bin/sops 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/sops
        print_success "SOPS installed"
    else
        print_info "SOPS already installed"
    fi
}

# Install age encryption
install_age() {
    print_header "Installing age"
    
    if ! command -v age &>/dev/null; then
        print_info "Installing age..."
        local version=$(curl -s https://api.github.com/repos/FiloSottile/age/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        cd /tmp
        curl -LO "https://github.com/FiloSottile/age/releases/download/v${version}/age-v${version}-linux-amd64.tar.gz" 2>&1 | tee -a "${LOG_FILE}"
        tar xvf age-v${version}-linux-amd64.tar.gz
        sudo cp age/age /usr/local/bin/
        sudo cp age/age-keygen /usr/local/bin/
        rm -rf age age-v${version}-linux-amd64.tar.gz
        print_success "age installed"
    else
        print_info "age already installed"
    fi
}

# Install pass (password store)
install_pass() {
    print_header "Installing pass"
    
    if ! rpm -q pass &>/dev/null; then
        print_info "Installing pass..."
        sudo dnf5 install -y pass 2>&1 | tee -a "${LOG_FILE}"
        print_success "pass installed"
    else
        print_info "pass already installed"
    fi
}

# Install security scanning tools
install_security_scanners() {
    print_header "Installing Security Scanning Tools"
    
    # Lynis
    if ! command -v lynis &>/dev/null; then
        print_info "Installing Lynis..."
        sudo dnf5 install -y lynis 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Lynis"
    fi
    
    # ClamAV
    local packages=(
        clamav
        clamav-update
        clamd
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Update ClamAV database
    if command -v freshclam &>/dev/null; then
        print_info "Updating ClamAV virus database..."
        sudo freshclam 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to update ClamAV database"
    fi
    
    # rkhunter
    if ! rpm -q rkhunter &>/dev/null; then
        print_info "Installing rkhunter..."
        sudo dnf5 install -y rkhunter 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install rkhunter"
    fi
    
    # chkrootkit
    if ! rpm -q chkrootkit &>/dev/null; then
        print_info "Installing chkrootkit..."
        sudo dnf5 install -y chkrootkit 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install chkrootkit"
    fi
    
    # Nuclei
    if ! command -v nuclei &>/dev/null; then
        print_info "Installing Nuclei..."
        go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Nuclei"
    fi
    
    print_success "Security scanning tools installed"
}

# Install certificate management tools
install_cert_tools() {
    print_header "Installing Certificate Management Tools"
    
    local packages=(
        openssl
        certbot
        python3-certbot-nginx
        python3-certbot-apache
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # cfssl
    if ! command -v cfssl &>/dev/null; then
        print_info "Installing cfssl..."
        go install github.com/cloudflare/cfssl/cmd/cfssl@latest 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install cfssl"
        go install github.com/cloudflare/cfssl/cmd/cfssljson@latest 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install cfssljson"
    fi
    
    # step-cli
    if ! command -v step &>/dev/null; then
        print_info "Installing step-cli..."
        local version=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        cd /tmp
        curl -LO "https://github.com/smallstep/cli/releases/download/v${version}/step_linux_${version}_amd64.tar.gz" 2>&1 | tee -a "${LOG_FILE}"
        tar xvf step_linux_${version}_amd64.tar.gz
        sudo cp step_${version}/bin/step /usr/local/bin/
        rm -rf step_${version} step_linux_${version}_amd64.tar.gz
        print_success "step-cli installed"
    else
        print_info "step-cli already installed"
    fi
    
    # mkcert
    if ! command -v mkcert &>/dev/null; then
        print_info "Installing mkcert..."
        local version=$(curl -s https://api.github.com/repos/FiloSottile/mkcert/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        sudo curl -L "https://github.com/FiloSottile/mkcert/releases/download/v${version}/mkcert-v${version}-linux-amd64" -o /usr/local/bin/mkcert 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/mkcert
        print_success "mkcert installed"
    else
        print_info "mkcert already installed"
    fi
    
    print_success "Certificate management tools installed"
}

# Install intrusion detection
install_ids() {
    print_header "Installing Intrusion Detection Systems"
    
    # AIDE
    if ! rpm -q aide &>/dev/null; then
        print_info "Installing AIDE..."
        sudo dnf5 install -y aide 2>&1 | tee -a "${LOG_FILE}"
        
        print_info "Initializing AIDE database..."
        sudo aide --init 2>&1 | tee -a "${LOG_FILE}" || print_warning "AIDE initialization incomplete"
        
        print_success "AIDE installed"
    else
        print_info "AIDE already installed"
    fi
}

# Install OpenSCAP
install_openscap() {
    print_header "Installing OpenSCAP"
    
    local packages=(
        openscap-scanner
        scap-security-guide
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "OpenSCAP installed"
}

# Install sealed secrets
install_sealed_secrets() {
    print_header "Installing Sealed Secrets (Kubeseal)"
    
    if ! command -v kubeseal &>/dev/null; then
        print_info "Installing kubeseal..."
        local version=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        sudo curl -L "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${version}/kubeseal-${version}-linux-amd64.tar.gz" | sudo tar xz -C /usr/local/bin kubeseal 2>&1 | tee -a "${LOG_FILE}"
        print_success "kubeseal installed"
    else
        print_info "kubeseal already installed"
    fi
}

# Create security scan script
create_security_scan_script() {
    print_header "Creating Security Scan Script"
    
    local scan_script="${HOME}/.local/bin/security-scan"
    mkdir -p "${HOME}/.local/bin"
    
    cat > "$scan_script" <<'EOF'
#!/bin/bash

echo "Running security scans..."
echo

if command -v lynis &>/dev/null; then
    echo "=== Lynis System Audit ==="
    sudo lynis audit system --quick
    echo
fi

if command -v rkhunter &>/dev/null; then
    echo "=== RKHunter Check ==="
    sudo rkhunter --check --skip-keypress --report-warnings-only
    echo
fi

if command -v clamscan &>/dev/null; then
    echo "=== ClamAV Scan (Home Directory) ==="
    clamscan -r --bell -i "$HOME"
    echo
fi

echo "Security scans completed!"
EOF
    
    chmod +x "$scan_script"
    print_success "Security scan script created: $scan_script"
}

# Main execution
main() {
    print_header "Fedora 43 Security & Secrets Management Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    install_vault
    install_sops
    install_age
    install_pass
    install_security_scanners
    install_cert_tools
    install_ids
    install_openscap
    install_sealed_secrets
    create_security_scan_script
    
    print_header "Installation Summary"
    print_success "Security & Secrets Management setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    echo "  - Secrets: Vault, SOPS, age, pass, kubeseal"
    echo "  - Security scanning: Lynis, ClamAV, rkhunter, chkrootkit, nuclei"
    echo "  - Certificates: certbot, cfssl, step-cli, mkcert"
    echo "  - IDS: AIDE"
    echo "  - Compliance: OpenSCAP"
    
    print_info "\nNext Steps:"
    echo "1. Initialize AIDE: sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz"
    echo "2. Setup Vault: vault server -dev (for development)"
    echo "3. Run security scan: ${HOME}/.local/bin/security-scan"
    echo "4. Setup local CA with mkcert: mkcert -install"
    echo "5. Initialize pass: pass init <gpg-key-id>"
    
    print_warning "\nSecurity Recommendations:"
    echo "  - Run regular security scans"
    echo "  - Keep ClamAV signatures updated: sudo freshclam"
    echo "  - Review Lynis recommendations"
    echo "  - Setup automated AIDE checks"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
