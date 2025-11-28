#!/bin/bash

#############################################
# Fedora 43 Setup - Containers & Orchestration
# Description: Container runtimes, Kubernetes tools, security scanning
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
LOG_FILE="${LOG_DIR}/03-containers-orchestration-$(date +%Y%m%d-%H%M%S).log"
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

# Install Podman ecosystem
install_podman() {
    print_header "Installing Podman Ecosystem"
    
    local packages=(
        podman
        podman-compose
        podman-docker
        buildah
        skopeo
        crun
        slirp4netns
        fuse-overlayfs
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Enable podman socket for docker compatibility
    print_info "Enabling Podman socket..."
    systemctl --user enable --now podman.socket 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to enable podman socket"
    
    print_success "Podman ecosystem installed"
}

# Install Docker
install_docker() {
    print_header "Installing Docker"
    
    # Add Docker repository
    if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
        print_info "Adding Docker repository..."
        sudo dnf5 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    local packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Start and enable Docker
    print_info "Starting and enabling Docker service..."
    sudo systemctl enable --now docker 2>&1 | tee -a "${LOG_FILE}"
    
    # Add user to docker group
    print_info "Adding user to docker group..."
    sudo usermod -aG docker "${USER}" 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Docker installed"
    print_warning "Please log out and back in for docker group membership to take effect"
}

# Install Kubernetes CLI tools
install_kubectl() {
    print_header "Installing Kubernetes CLI Tools"
    
    # Add Kubernetes repository
    if [[ ! -f /etc/yum.repos.d/kubernetes.repo ]]; then
        print_info "Adding Kubernetes repository..."
        cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF
    fi
    
    local packages=(
        kubectl
        kubelet
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Kubernetes CLI tools installed"
}

# Install Helm
install_helm() {
    print_header "Installing Helm"
    
    if ! command -v helm &>/dev/null; then
        print_info "Installing Helm..."
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash 2>&1 | tee -a "${LOG_FILE}"
        print_success "Helm installed"
    else
        print_info "Helm already installed"
    fi
}

# Install k9s
install_k9s() {
    print_header "Installing k9s"
    
    if ! command -v k9s &>/dev/null; then
        print_info "Installing k9s..."
        local k9s_version=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -sL "https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin k9s 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/k9s
        print_success "k9s installed"
    else
        print_info "k9s already installed"
    fi
}

# Install kubectx and kubens
install_kubectx() {
    print_header "Installing kubectx and kubens"
    
    if ! command -v kubectx &>/dev/null; then
        print_info "Installing kubectx and kubens..."
        sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx 2>&1 | tee -a "${LOG_FILE}"
        sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
        sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
        print_success "kubectx and kubens installed"
    else
        print_info "kubectx already installed"
    fi
}

# Install kustomize
install_kustomize() {
    print_header "Installing Kustomize"
    
    if ! command -v kustomize &>/dev/null; then
        print_info "Installing kustomize..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash 2>&1 | tee -a "${LOG_FILE}"
        sudo mv kustomize /usr/local/bin/
        print_success "Kustomize installed"
    else
        print_info "Kustomize already installed"
    fi
}

# Install Minikube
install_minikube() {
    print_header "Installing Minikube"
    
    if ! command -v minikube &>/dev/null; then
        print_info "Installing Minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 2>&1 | tee -a "${LOG_FILE}"
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        print_success "Minikube installed"
    else
        print_info "Minikube already installed"
    fi
}

# Install kind
install_kind() {
    print_header "Installing kind (Kubernetes in Docker)"
    
    if ! command -v kind &>/dev/null; then
        print_info "Installing kind..."
        local kind_version=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-amd64" 2>&1 | tee -a "${LOG_FILE}"
        sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
        rm kind
        print_success "kind installed"
    else
        print_info "kind already installed"
    fi
}

# Install stern
install_stern() {
    print_header "Installing Stern"
    
    if ! command -v stern &>/dev/null; then
        print_info "Installing stern..."
        local stern_version=$(curl -s https://api.github.com/repos/stern/stern/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -sL "https://github.com/stern/stern/releases/download/${stern_version}/stern_${stern_version#v}_linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin stern 2>&1 | tee -a "${LOG_FILE}"
        print_success "Stern installed"
    else
        print_info "Stern already installed"
    fi
}

# Install container security tools
install_security_tools() {
    print_header "Installing Container Security Tools"
    
    # Trivy
    if ! command -v trivy &>/dev/null; then
        print_info "Installing Trivy..."
        local trivy_version=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -sL "https://github.com/aquasecurity/trivy/releases/download/${trivy_version}/trivy_${trivy_version#v}_Linux-64bit.tar.gz" | sudo tar xz -C /usr/local/bin trivy 2>&1 | tee -a "${LOG_FILE}"
        print_success "Trivy installed"
    else
        print_info "Trivy already installed"
    fi
    
    # Grype
    if ! command -v grype &>/dev/null; then
        print_info "Installing Grype..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin 2>&1 | tee -a "${LOG_FILE}"
        print_success "Grype installed"
    else
        print_info "Grype already installed"
    fi
    
    # Syft
    if ! command -v syft &>/dev/null; then
        print_info "Installing Syft..."
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin 2>&1 | tee -a "${LOG_FILE}"
        print_success "Syft installed"
    else
        print_info "Syft already installed"
    fi
}

# Configure kubectl completion
configure_kubectl_completion() {
    print_header "Configuring kubectl Completion"
    
    if command -v kubectl &>/dev/null; then
        print_info "Setting up kubectl completion..."
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
        kubectl completion zsh | sudo tee /usr/share/zsh/site-functions/_kubectl > /dev/null
        print_success "kubectl completion configured"
    fi
}

# Main execution
main() {
    print_header "Fedora 43 Containers & Orchestration Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    install_podman
    
    # Ask user if they want Docker
    read -p "Do you want to install Docker? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_docker
    else
        print_info "Skipping Docker installation"
    fi
    
    install_kubectl
    install_helm
    install_k9s
    install_kubectx
    install_kustomize
    install_minikube
    install_kind
    install_stern
    install_security_tools
    configure_kubectl_completion
    
    print_header "Installation Summary"
    print_success "Containers & Orchestration setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    echo "  - Podman ecosystem (podman, buildah, skopeo)"
    [[ $REPLY =~ ^[Yy]$ ]] && echo "  - Docker Engine"
    echo "  - Kubernetes tools (kubectl, helm, k9s, kubectx, kubens)"
    echo "  - Local clusters (minikube, kind)"
    echo "  - Security scanning (trivy, grype, syft)"
    
    print_info "\nNext Steps:"
    echo "1. Log out and back in for group memberships to take effect"
    echo "2. Test installations:"
    echo "   - podman --version"
    echo "   - kubectl version --client"
    echo "   - helm version"
    echo "3. Start a local cluster: minikube start (or) kind create cluster"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
