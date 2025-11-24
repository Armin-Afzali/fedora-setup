#!/bin/bash

#############################################
# Fedora 43 Setup - Cloud Provider CLIs & Tools
# Description: AWS, Azure, GCP, and multi-cloud tools
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
LOG_FILE="${LOG_DIR}/04-cloud-providers-$(date +%Y%m%d-%H%M%S).log"
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

# Install AWS CLI v2
install_aws_cli() {
    print_header "Installing AWS CLI v2"
    
    if ! command -v aws &>/dev/null; then
        print_info "Downloading and installing AWS CLI v2..."
        cd /tmp
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" 2>&1 | tee -a "${LOG_FILE}"
        unzip -q awscliv2.zip
        sudo ./aws/install 2>&1 | tee -a "${LOG_FILE}"
        rm -rf aws awscliv2.zip
        print_success "AWS CLI v2 installed"
    else
        print_info "AWS CLI already installed: $(aws --version)"
    fi
}

# Install AWS tools
install_aws_tools() {
    print_header "Installing AWS Tools"
    
    # eksctl
    if ! command -v eksctl &>/dev/null; then
        print_info "Installing eksctl..."
        curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin 2>&1 | tee -a "${LOG_FILE}"
        print_success "eksctl installed"
    else
        print_info "eksctl already installed"
    fi
    
    # aws-vault
    if ! command -v aws-vault &>/dev/null; then
        print_info "Installing aws-vault..."
        local vault_version=$(curl -s https://api.github.com/repos/99designs/aws-vault/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/99designs/aws-vault/releases/download/${vault_version}/aws-vault-linux-amd64" -o /usr/local/bin/aws-vault 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/aws-vault
        print_success "aws-vault installed"
    else
        print_info "aws-vault already installed"
    fi
    
    # Session Manager Plugin
    if ! command -v session-manager-plugin &>/dev/null; then
        print_info "Installing AWS Session Manager Plugin..."
        cd /tmp
        curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm" 2>&1 | tee -a "${LOG_FILE}"
        sudo dnf5 install -y ./session-manager-plugin.rpm 2>&1 | tee -a "${LOG_FILE}"
        rm -f session-manager-plugin.rpm
        print_success "Session Manager Plugin installed"
    else
        print_info "Session Manager Plugin already installed"
    fi
}

# Install Azure CLI
install_azure_cli() {
    print_header "Installing Azure CLI"
    
    if ! command -v az &>/dev/null; then
        print_info "Adding Microsoft repository..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>&1 | tee -a "${LOG_FILE}"
        
        echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
        
        print_info "Installing Azure CLI..."
        sudo dnf5 install -y azure-cli 2>&1 | tee -a "${LOG_FILE}"
        print_success "Azure CLI installed"
    else
        print_info "Azure CLI already installed: $(az --version | head -n1)"
    fi
}

# Install Google Cloud SDK
install_gcloud() {
    print_header "Installing Google Cloud SDK"
    
    if ! command -v gcloud &>/dev/null; then
        print_info "Adding Google Cloud repository..."
        sudo tee /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
        
        print_info "Installing Google Cloud SDK..."
        sudo dnf5 install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin 2>&1 | tee -a "${LOG_FILE}"
        print_success "Google Cloud SDK installed"
    else
        print_info "Google Cloud SDK already installed"
    fi
}

# Install Terraform
install_terraform() {
    print_header "Installing Terraform"
    
    if ! command -v terraform &>/dev/null; then
        print_info "Adding HashiCorp repository..."
        sudo dnf5 config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>&1 | tee -a "${LOG_FILE}"
        
        print_info "Installing Terraform..."
        sudo dnf5 install -y terraform 2>&1 | tee -a "${LOG_FILE}"
        print_success "Terraform installed"
    else
        print_info "Terraform already installed: $(terraform version | head -n1)"
    fi
}

# Install Terraform tools
install_terraform_tools() {
    print_header "Installing Terraform Tools"
    
    # terraform-docs
    if ! command -v terraform-docs &>/dev/null; then
        print_info "Installing terraform-docs..."
        local version=$(curl -s https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -sL "https://github.com/terraform-docs/terraform-docs/releases/download/${version}/terraform-docs-${version}-linux-amd64.tar.gz" | sudo tar xz -C /usr/local/bin terraform-docs 2>&1 | tee -a "${LOG_FILE}"
        print_success "terraform-docs installed"
    else
        print_info "terraform-docs already installed"
    fi
    
    # tflint
    if ! command -v tflint &>/dev/null; then
        print_info "Installing tflint..."
        curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash 2>&1 | tee -a "${LOG_FILE}"
        print_success "tflint installed"
    else
        print_info "tflint already installed"
    fi
    
    # tfsec
    if ! command -v tfsec &>/dev/null; then
        print_info "Installing tfsec..."
        local version=$(curl -s https://api.github.com/repos/aquasecurity/tfsec/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -sL "https://github.com/aquasecurity/tfsec/releases/download/${version}/tfsec-linux-amd64" -o /tmp/tfsec 2>&1 | tee -a "${LOG_FILE}"
        sudo install /tmp/tfsec /usr/local/bin/tfsec
        rm /tmp/tfsec
        print_success "tfsec installed"
    else
        print_info "tfsec already installed"
    fi
    
    # terragrunt
    if ! command -v terragrunt &>/dev/null; then
        print_info "Installing terragrunt..."
        local version=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/gruntwork-io/terragrunt/releases/download/${version}/terragrunt_linux_amd64" -o /usr/local/bin/terragrunt 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/terragrunt
        print_success "terragrunt installed"
    else
        print_info "terragrunt already installed"
    fi
}

# Install OpenTofu
install_opentofu() {
    print_header "Installing OpenTofu"
    
    if ! command -v tofu &>/dev/null; then
        print_info "Installing OpenTofu..."
        curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh 2>&1 | tee -a "${LOG_FILE}"
        chmod +x install-opentofu.sh
        sudo ./install-opentofu.sh --install-method rpm 2>&1 | tee -a "${LOG_FILE}"
        rm install-opentofu.sh
        print_success "OpenTofu installed"
    else
        print_info "OpenTofu already installed"
    fi
}

# Install Pulumi
install_pulumi() {
    print_header "Installing Pulumi"
    
    if ! command -v pulumi &>/dev/null; then
        print_info "Installing Pulumi..."
        curl -fsSL https://get.pulumi.com | sh 2>&1 | tee -a "${LOG_FILE}"
        
        # Add to PATH for current session
        export PATH="$HOME/.pulumi/bin:$PATH"
        
        print_success "Pulumi installed"
        print_info "Add to your shell rc: export PATH=\"\$HOME/.pulumi/bin:\$PATH\""
    else
        print_info "Pulumi already installed"
    fi
}

# Install cloud-nuke
install_cloud_nuke() {
    print_header "Installing cloud-nuke"
    
    if ! command -v cloud-nuke &>/dev/null; then
        print_info "Installing cloud-nuke..."
        local version=$(curl -s https://api.github.com/repos/gruntwork-io/cloud-nuke/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -sL "https://github.com/gruntwork-io/cloud-nuke/releases/download/${version}/cloud-nuke_linux_amd64" -o /tmp/cloud-nuke 2>&1 | tee -a "${LOG_FILE}"
        sudo install /tmp/cloud-nuke /usr/local/bin/cloud-nuke
        rm /tmp/cloud-nuke
        print_success "cloud-nuke installed"
    else
        print_info "cloud-nuke already installed"
    fi
}

# Configure shell completions
configure_completions() {
    print_header "Configuring Shell Completions"
    
    local completion_dir="${HOME}/.fedora-setup-completions"
    mkdir -p "$completion_dir"
    
    if command -v aws &>/dev/null; then
        aws --completion > "${completion_dir}/aws_completion.sh" 2>/dev/null || true
    fi
    
    if command -v az &>/dev/null; then
        az completion > "${completion_dir}/az_completion.sh" 2>/dev/null || true
    fi
    
    if command -v terraform &>/dev/null; then
        terraform -install-autocomplete 2>&1 | tee -a "${LOG_FILE}" || true
    fi
    
    print_success "Shell completions configured"
    print_info "Completions saved in: ${completion_dir}"
}

# Main execution
main() {
    print_header "Fedora 43 Cloud Provider CLIs & Tools Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    # Ask which cloud providers to install
    echo "Which cloud providers do you want to install?"
    read -p "Install AWS tools? (y/n) " -n 1 -r aws_install
    echo
    read -p "Install Azure tools? (y/n) " -n 1 -r azure_install
    echo
    read -p "Install Google Cloud tools? (y/n) " -n 1 -r gcp_install
    echo
    
    [[ $aws_install =~ ^[Yy]$ ]] && install_aws_cli && install_aws_tools
    [[ $azure_install =~ ^[Yy]$ ]] && install_azure_cli
    [[ $gcp_install =~ ^[Yy]$ ]] && install_gcloud
    
    install_terraform
    install_terraform_tools
    install_opentofu
    install_pulumi
    install_cloud_nuke
    configure_completions
    
    print_header "Installation Summary"
    print_success "Cloud Provider CLIs & Tools setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    [[ $aws_install =~ ^[Yy]$ ]] && echo "  - AWS CLI v2, eksctl, aws-vault, Session Manager"
    [[ $azure_install =~ ^[Yy]$ ]] && echo "  - Azure CLI"
    [[ $gcp_install =~ ^[Yy]$ ]] && echo "  - Google Cloud SDK"
    echo "  - Terraform and tools (terraform-docs, tflint, tfsec, terragrunt)"
    echo "  - OpenTofu, Pulumi, cloud-nuke"
    
    print_info "\nNext Steps:"
    echo "1. Configure cloud credentials:"
    [[ $aws_install =~ ^[Yy]$ ]] && echo "   - aws configure"
    [[ $azure_install =~ ^[Yy]$ ]] && echo "   - az login"
    [[ $gcp_install =~ ^[Yy]$ ]] && echo "   - gcloud init"
    echo "2. Test installations with version commands"
    echo "3. Review completions in: ${HOME}/.fedora-setup-completions"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
