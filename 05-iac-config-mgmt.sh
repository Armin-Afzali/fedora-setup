#!/bin/bash

#############################################
# Fedora 43 Setup - IaC & Configuration Management
# Description: Ansible, Packer, Vagrant, Puppet, Salt, Chef
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
LOG_FILE="${LOG_DIR}/05-iac-config-mgmt-$(date +%Y%m%d-%H%M%S).log"
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

# Install Ansible
install_ansible() {
    print_header "Installing Ansible"
    
    local packages=(
        ansible
        ansible-core
        ansible-lint
        python3-pip
        python3-argcomplete
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install additional Ansible collections via pip
    print_info "Installing useful Ansible collections..."
    pip3 install --user ansible-navigator molecule molecule-plugins[docker] 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install some Python packages"
    
    print_success "Ansible installed"
}

# Install Packer
install_packer() {
    print_header "Installing Packer"
    
    if ! command -v packer &>/dev/null; then
        print_info "Installing Packer from HashiCorp repository..."
        
        # HashiCorp repo should be added already, but check
        if [[ ! -f /etc/yum.repos.d/hashicorp.repo ]]; then
            sudo dnf5 config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>&1 | tee -a "${LOG_FILE}"
        fi
        
        sudo dnf5 install -y packer 2>&1 | tee -a "${LOG_FILE}"
        print_success "Packer installed"
    else
        print_info "Packer already installed: $(packer version)"
    fi
}

# Install Vagrant
install_vagrant() {
    print_header "Installing Vagrant"
    
    if ! command -v vagrant &>/dev/null; then
        print_info "Installing Vagrant from HashiCorp repository..."
        
        if [[ ! -f /etc/yum.repos.d/hashicorp.repo ]]; then
            sudo dnf5 config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>&1 | tee -a "${LOG_FILE}"
        fi
        
        sudo dnf5 install -y vagrant 2>&1 | tee -a "${LOG_FILE}"
        print_success "Vagrant installed"
    else
        print_info "Vagrant already installed: $(vagrant --version)"
    fi
    
    # Install vagrant-libvirt plugin
    if command -v vagrant &>/dev/null; then
        print_info "Installing Vagrant libvirt plugin dependencies..."
        sudo dnf5 install -y gcc libvirt libvirt-devel ruby-devel 2>&1 | tee -a "${LOG_FILE}"
        
        print_info "Installing vagrant-libvirt plugin..."
        vagrant plugin install vagrant-libvirt 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install vagrant-libvirt"
        print_success "Vagrant libvirt plugin installed"
    fi
}

# Install libvirt for virtualization
install_libvirt() {
    print_header "Installing Libvirt for Virtualization"
    
    local packages=(
        @virtualization
        libvirt
        libvirt-daemon-kvm
        qemu-kvm
        virt-manager
        virt-install
        virt-viewer
        bridge-utils
        libguestfs-tools
    )
    
    for pkg in "${packages[@]}"; do
        if [[ $pkg == @* ]]; then
            # Group install
            print_info "Installing group $pkg..."
            sudo dnf5 group install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install group $pkg"
        else
            if ! rpm -q "$pkg" &>/dev/null; then
                print_info "Installing $pkg..."
                sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
            else
                print_info "$pkg already installed"
            fi
        fi
    done
    
    # Enable and start libvirtd
    print_info "Enabling libvirtd service..."
    sudo systemctl enable --now libvirtd 2>&1 | tee -a "${LOG_FILE}"
    
    # Add user to libvirt group
    print_info "Adding user to libvirt group..."
    sudo usermod -aG libvirt "${USER}" 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Libvirt installed and configured"
}

# Install Puppet
install_puppet() {
    print_header "Installing Puppet"
    
    if ! command -v puppet &>/dev/null; then
        print_info "Adding Puppet repository..."
        sudo rpm -Uvh https://yum.puppet.com/puppet8-release-fedora-33.noarch.rpm 2>&1 | tee -a "${LOG_FILE}" || true
        
        print_info "Installing Puppet..."
        sudo dnf5 install -y puppet 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Puppet"
        
        # Add puppet to PATH
        if [[ -d /opt/puppetlabs/bin ]]; then
            export PATH="/opt/puppetlabs/bin:$PATH"
            print_success "Puppet installed"
            print_info "Add to your shell rc: export PATH=\"/opt/puppetlabs/bin:\$PATH\""
        fi
    else
        print_info "Puppet already installed"
    fi
}

# Install SaltStack
install_salt() {
    print_header "Installing SaltStack"
    
    local packages=(
        salt-master
        salt-minion
        salt-ssh
        salt-syndic
        salt-api
    )
    
    # Ask user which components to install
    read -p "Install Salt Master? (y/n) " -n 1 -r salt_master
    echo
    read -p "Install Salt Minion? (y/n) " -n 1 -r salt_minion
    echo
    
    if [[ $salt_master =~ ^[Yy]$ ]]; then
        if ! rpm -q salt-master &>/dev/null; then
            print_info "Installing Salt Master..."
            sudo dnf5 install -y salt-master 2>&1 | tee -a "${LOG_FILE}"
            sudo systemctl enable --now salt-master 2>&1 | tee -a "${LOG_FILE}"
            print_success "Salt Master installed"
        else
            print_info "Salt Master already installed"
        fi
    fi
    
    if [[ $salt_minion =~ ^[Yy]$ ]]; then
        if ! rpm -q salt-minion &>/dev/null; then
            print_info "Installing Salt Minion..."
            sudo dnf5 install -y salt-minion 2>&1 | tee -a "${LOG_FILE}"
            print_success "Salt Minion installed"
            print_info "Configure /etc/salt/minion and then: sudo systemctl enable --now salt-minion"
        else
            print_info "Salt Minion already installed"
        fi
    fi
    
    # Install salt-ssh regardless
    if ! rpm -q salt-ssh &>/dev/null; then
        print_info "Installing Salt SSH..."
        sudo dnf5 install -y salt-ssh 2>&1 | tee -a "${LOG_FILE}"
    fi
}

# Install Chef Workstation
install_chef() {
    print_header "Installing Chef Workstation"
    
    if ! command -v chef &>/dev/null; then
        print_info "Downloading Chef Workstation..."
        cd /tmp
        curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Chef Workstation"
        
        if command -v chef &>/dev/null; then
            print_success "Chef Workstation installed"
        else
            print_warning "Chef Workstation installation may have failed"
        fi
    else
        print_info "Chef already installed: $(chef --version | head -n1)"
    fi
}

# Configure Ansible
configure_ansible() {
    print_header "Configuring Ansible"
    
    # Create ansible directory structure
    local ansible_dir="${HOME}/.ansible"
    mkdir -p "${ansible_dir}"/{inventory,roles,playbooks}
    
    # Create sample ansible.cfg
    if [[ ! -f "${ansible_dir}/ansible.cfg" ]]; then
        print_info "Creating sample ansible.cfg..."
        cat > "${ansible_dir}/ansible.cfg" <<'EOF'
[defaults]
inventory = ${HOME}/.ansible/inventory
roles_path = ${HOME}/.ansible/roles
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
EOF
        print_success "Sample ansible.cfg created"
    fi
    
    print_info "Ansible configuration directory: ${ansible_dir}"
}

# Main execution
main() {
    print_header "Fedora 43 IaC & Configuration Management Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    install_ansible
    configure_ansible
    install_packer
    install_libvirt
    install_vagrant
    
    # Ask about additional config management tools
    read -p "Install Puppet? (y/n) " -n 1 -r install_puppet
    echo
    read -p "Install SaltStack? (y/n) " -n 1 -r install_saltstack
    echo
    read -p "Install Chef Workstation? (y/n) " -n 1 -r install_chef_ws
    echo
    
    [[ $install_puppet =~ ^[Yy]$ ]] && install_puppet
    [[ $install_saltstack =~ ^[Yy]$ ]] && install_salt
    [[ $install_chef_ws =~ ^[Yy]$ ]] && install_chef
    
    print_header "Installation Summary"
    print_success "IaC & Configuration Management setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    echo "  - Ansible with ansible-lint"
    echo "  - Packer"
    echo "  - Vagrant with libvirt support"
    echo "  - Libvirt/KVM virtualization"
    [[ $install_puppet =~ ^[Yy]$ ]] && echo "  - Puppet"
    [[ $install_saltstack =~ ^[Yy]$ ]] && echo "  - SaltStack"
    [[ $install_chef_ws =~ ^[Yy]$ ]] && echo "  - Chef Workstation"
    
    print_info "\nNext Steps:"
    echo "1. Log out and back in for group memberships to take effect"
    echo "2. Configure Ansible: ${HOME}/.ansible/ansible.cfg"
    echo "3. Test libvirt: virsh list --all"
    echo "4. Test Vagrant: vagrant --version"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
