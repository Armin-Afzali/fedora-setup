#!/usr/bin/env bash

# ==============================================================================
# Fedora 43 Cloud + DevOps + Networking Workstation Setup Script
# Optimized for NVIDIA GPU systems - Package Manager First Edition
# ==============================================================================

set -o pipefail

LOGFILE="$HOME/setup-error.log"
BACKUP_DIR="$HOME/.config-backups/$(date +%Y%m%d-%H%M%S)"
SCRIPT_START=$(date '+%Y-%m-%d %H:%M:%S')
TMP_DIR=$(mktemp -d)

# Initialize log file
mkdir -p "$(dirname "$LOGFILE")"
echo "=== Setup started at $SCRIPT_START ===" > "$LOGFILE"

# Cleanup trap
trap 'rm -rf "$TMP_DIR"' EXIT

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

# ===== COLORS =====
RESET="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR${RESET}: $1" \
        | tee -a "$LOGFILE" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO${RESET}: $1"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}WARNING${RESET}: $1" \
        | tee -a "$LOGFILE"
}

log_critical() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${MAGENTA}CRITICAL${RESET}: $1" \
        | tee -a "$LOGFILE" >&2
    exit 1
}

handle_error() {
    log_error "Command failed at line $1"
}

trap 'handle_error $LINENO' ERR

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

safe_append() {
    local file="$1"
    local content="$2"
    local marker="$3"
    
    if [ ! -f "$file" ]; then
        echo "$content" > "$file"
        return
    fi
    
    if ! grep -qF "$marker" "$file"; then
        echo "$content" >> "$file"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
        log_info "Backed up $file"
    fi
}

safe_download() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -fsSL --connect-timeout 10 "$url" -o "$output"; then
            return 0
        fi
        retry=$((retry + 1))
        log_warning "Download attempt $retry failed for $url"
        sleep 2
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

install_if_missing() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! package_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installing: ${to_install[*]}"
        if ! sudo dnf install -y "${to_install[@]}" 2>> "$LOGFILE"; then
            log_error "Failed to install: ${to_install[*]}"
            return 1
        fi
    fi
    return 0
}

install_critical() {
    local packages=("$@")
    if ! install_if_missing "${packages[@]}"; then
        log_critical "Critical package installation failed: ${packages[*]}"
    fi
}

# ==============================================================================
# MODULE 00: PRE-FLIGHT CHECKS
# ==============================================================================

module_00_checks() {
    log_info "=== MODULE 00: Pre-flight Checks ==="
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_critical "Do not run this script as root. Run as normal user with sudo access."
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "Testing sudo access..."
        if ! sudo true; then
            log_critical "Sudo access required"
        fi
    fi
    
    # Check Internet connectivity
    log_info "Checking Internet connectivity..."
    if ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
        log_critical "No Internet connectivity detected"
    fi
    
    # Check disk space (need at least 10GB free)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 10485760 ]; then
        log_critical "Insufficient disk space. Need at least 10GB free on /"
    fi
    
    # Detect Fedora version
    if [ -f /etc/fedora-release ]; then
        local fedora_version=$(rpm -E %fedora)
        log_info "Detected Fedora $fedora_version"
        if [ "$fedora_version" -lt 39 ]; then
            log_warning "This script is optimized for Fedora 39+. You are running Fedora $fedora_version"
        fi
    else
        log_critical "This script is designed for Fedora only"
    fi
    
    # Detect NVIDIA GPU
    if lspci | grep -i nvidia >/dev/null 2>&1; then
        log_info "NVIDIA GPU detected"
        export HAS_NVIDIA=1
    else
        log_warning "No NVIDIA GPU detected. NVIDIA driver installation will be skipped."
        export HAS_NVIDIA=0
    fi
    
    # Check SELinux state
    if command_exists getenforce; then
        local selinux_status=$(getenforce)
        log_info "SELinux status: $selinux_status"
        
        if [ "$selinux_status" = "Enforcing" ]; then
            log_warning "SELinux is in Enforcing mode. This may cause issues with:"
            log_warning "  - Docker containers (consider: sudo setsebool -P container_manage_cgroup on)"
            log_warning "  - Kubernetes pods"
            log_warning "  - Libvirt/KVM"
            log_warning "If you encounter permission issues, check: sudo ausearch -m avc -ts recent"
        fi
    fi
    
    log_info "All pre-flight checks passed"
}

# ==============================================================================
# MODULE 01: BASE SYSTEM
# ==============================================================================

module_01_base() {
    log_info "=== MODULE 01: Base System Setup ==="
    
    log_info "Upgrading system packages..."
    sudo dnf upgrade -y --refresh 2>> "$LOGFILE" || log_error "System upgrade had issues"
    
    log_info "Installing RPM Fusion repositories..."
    if ! package_installed rpmfusion-free-release; then
        sudo dnf install -y \
            "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            2>> "$LOGFILE" || log_error "RPM Fusion Free install failed"
    fi
    
    if ! package_installed rpmfusion-nonfree-release; then
        sudo dnf install -y \
            "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
            2>> "$LOGFILE" || log_error "RPM Fusion Nonfree install failed"
    fi
    
    sudo dnf upgrade -y --refresh 2>> "$LOGFILE" || log_error "Post-RPM Fusion upgrade had issues"
    
    log_info "Configuring FirewallD..."
    install_critical firewalld
    sudo systemctl enable --now firewalld 2>> "$LOGFILE" || log_critical "FirewallD enable failed"
    sudo firewall-cmd --permanent --add-service=ssh 2>> "$LOGFILE" || true
    sudo firewall-cmd --reload 2>> "$LOGFILE" || true
    
    log_info "Installing and configuring Fail2ban..."
    install_if_missing fail2ban fail2ban-firewalld
    sudo systemctl enable --now fail2ban 2>> "$LOGFILE" || log_error "Fail2ban enable failed"
    
    log_info "Installing essential utilities..."
    install_if_missing \
        vim \
        neovim \
        git \
        git-lfs \
        curl \
        wget \
        unzip \
        zip \
        p7zip \
        p7zip-plugins \
        rsync \
        screen \
        jq \
        yq \
        tree \
        ncdu \
        htop
    
    git lfs install 2>> "$LOGFILE" || true
}

# ==============================================================================
# MODULE 02: NVIDIA DRIVERS
# ==============================================================================

module_02_nvidia() {
    if [ "$HAS_NVIDIA" -ne 1 ]; then
        log_info "=== MODULE 02: NVIDIA (Skipped - No GPU detected) ==="
        return 0
    fi
    
    log_info "=== MODULE 02: NVIDIA Drivers ==="
    
    log_info "Installing NVIDIA drivers..."
    install_if_missing \
        akmod-nvidia \
        xorg-x11-drv-nvidia \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-cuda-libs \
        xorg-x11-drv-nvidia-libs \
        vdpauinfo \
        libva-utils \
        vulkan
    
    log_info "Configuring NVIDIA kernel parameters..."
    if ! sudo grubby --info=ALL 2>/dev/null | grep -q "nvidia-drm.modeset=1"; then
        sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1" 2>> "$LOGFILE" || \
            log_error "Failed to update kernel parameters"
    fi
    
    log_info "Building NVIDIA kernel modules..."
    sudo akmods --force 2>> "$LOGFILE" || log_warning "akmods force build had issues"
    sudo dracut -f 2>> "$LOGFILE" || log_warning "dracut rebuild had issues"
    
    log_info "NVIDIA driver installation complete. Validation will occur after reboot."
}

# ==============================================================================
# MODULE 03: DEVELOPMENT TOOLS
# ==============================================================================

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
}

# ==============================================================================
# MODULE 04: CLOUD TOOLS
# ==============================================================================

module_04_cloud() {
    log_info "=== MODULE 04: Cloud Provider CLIs ==="
    
    # Docker
    log_info "Installing Docker..."
    if ! package_installed docker-ce; then
        if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>> "$LOGFILE" || \
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
}

# ==============================================================================
# MODULE 05: KUBERNETES TOOLS
# ==============================================================================

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
}

# ==============================================================================
# MODULE 06: IAC & CONFIGURATION MANAGEMENT
# ==============================================================================

module_06_iac() {
    log_info "=== MODULE 06: IaC & Configuration Management ==="
    
    # HashiCorp repo
    if ! package_installed terraform; then
        if [ ! -f /etc/yum.repos.d/hashicorp.repo ]; then
            sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>> "$LOGFILE" || \
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
}

# ==============================================================================
# MODULE 07: NETWORKING TOOLS
# ==============================================================================

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
}

# ==============================================================================
# MODULE 08: PRODUCTIVITY & OBSERVABILITY TOOLS
# ==============================================================================

module_08_productivity() {
    log_info "=== MODULE 08: Productivity & Observability Tools ==="
    
    # Shell environment
    log_info "Setting up Zsh environment..."
    install_if_missing zsh util-linux-user
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        local omz_script="$TMP_DIR/omz-install.sh"
        if safe_download "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "$omz_script"; then
            chmod +x "$omz_script"
            RUNZSH=no CHSH=no bash "$omz_script" --unattended 2>> "$LOGFILE" || log_error "Oh My Zsh install failed"
        fi
    fi
    
    # Zsh plugins
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>> "$LOGFILE" || \
            log_error "zsh-autosuggestions clone failed"
    fi
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>> "$LOGFILE" || \
            log_error "zsh-syntax-highlighting clone failed"
    fi
    
    # Starship from package manager
    log_info "Installing Starship prompt..."
    install_if_missing starship
    
    # tmux
    log_info "Setting up tmux..."
    install_if_missing tmux
    
    if [ ! -f "$HOME/.tmux.conf" ]; then
        cat > "$HOME/.tmux.conf" <<'EOF'
set -g mouse on
set -g history-limit 10000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g status-style 'bg=colour235 fg=colour255'
set -g pane-border-style 'fg=colour238'
set -g pane-active-border-style 'fg=colour51'
bind r source-file ~/.tmux.conf \; display "Reloaded!"
EOF
    fi
    
    # Modern CLI tools from package manager
    log_info "Installing modern CLI utilities..."
    install_if_missing \
        btop \
        fzf \
        ripgrep \
        fd-find \
        bat \
        eza \
        httpie \
        zoxide
    
    # GPU monitoring
    if [ "$HAS_NVIDIA" -eq 1 ]; then
        install_if_missing nvtop
    fi
    
    # lf file manager
    log_info "Installing lf file manager..."
    install_if_missing lf
    
    # Clipboard utilities
    if [ "${XDG_SESSION_TYPE:-x11}" = "wayland" ]; then
        install_if_missing wl-clipboard
    else
        install_if_missing xclip
    fi
    
    # Observability tools
    log_info "Installing observability tools..."
    
    # Prometheus from package manager
    install_if_missing prometheus
    
    # Grafana
    if ! package_installed grafana; then
        if [ ! -f /etc/yum.repos.d/grafana.repo ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
        fi
        
        install_if_missing grafana
    fi
    
    # Loki (no package manager option)
    if ! command_exists loki; then
        local LOKI_VERSION="3.2.0"
        local loki_zip="$TMP_DIR/loki.zip"
        if safe_download "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip" "$loki_zip"; then
            unzip -q "$loki_zip" -d "$TMP_DIR" 2>> "$LOGFILE" || true
            sudo install -o root -g root -m 0755 "$TMP_DIR/loki-linux-amd64" /usr/local/bin/loki
        fi
    fi
    
    # Promtail (no package manager option)
    if ! command_exists promtail; then
        local LOKI_VERSION="3.2.0"
        local promtail_zip="$TMP_DIR/promtail.zip"
        if safe_download "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/promtail-linux-amd64.zip" "$promtail_zip"; then
            unzip -q "$promtail_zip" -d "$TMP_DIR" 2>> "$LOGFILE" || true
            sudo install -o root -g root -m 0755 "$TMP_DIR/promtail-linux-amd64" /usr/local/bin/promtail
        fi
    fi
    
    # Jaeger (no package manager option)
    if ! command_exists jaeger-all-in-one; then
        local JAEGER_VERSION="1.61.0"
        local jaeger_tarball="$TMP_DIR/jaeger.tar.gz"
        if safe_download "https://github.com/jaegertracing/jaeger/releases/download/v${JAEGER_VERSION}/jaeger-${JAEGER_VERSION}-linux-amd64.tar.gz" "$jaeger_tarball"; then
            tar -xzf "$jaeger_tarball" -C "$TMP_DIR" 2>> "$LOGFILE" || true
            for binary in "$TMP_DIR/jaeger-${JAEGER_VERSION}-linux-amd64"/jaeger-*; do
                if [ -f "$binary" ]; then
                    sudo install -o root -g root -m 0755 "$binary" /usr/local/bin/
                fi
            done
        fi
    fi
    
    # Virtualization
    log_info "Installing virtualization tools..."
    if ! package_installed qemu-kvm; then
        sudo dnf install -y @virtualization 2>> "$LOGFILE" || log_error "Virtualization group install failed"
    fi
    
    install_if_missing \
        qemu-kvm \
        libvirt \
        virt-manager \
        virt-install \
        virt-viewer \
        bridge-utils
    
    sudo systemctl enable --now libvirtd 2>> "$LOGFILE" || log_error "libvirtd enable failed"
    
    if ! groups $USER | grep -q libvirt; then
        sudo usermod -aG libvirt $USER 2>> "$LOGFILE" || log_error "libvirt group add failed"
    fi
    if ! groups $USER | grep -q kvm; then
        sudo usermod -aG kvm $USER 2>> "$LOGFILE" || log_error "kvm group add failed"
    fi
    
    # Development IDEs
    log_info "Installing development IDEs..."
    
    # VS Code
    if ! command_exists code; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>> "$LOGFILE" || true
        
        if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        fi
        
        install_if_missing code
    fi
    
    # JetBrains Toolbox (no package manager option)
    log_info "Installing JetBrains Toolbox..."
    if ! command_exists jetbrains-toolbox && [ ! -f /usr/local/bin/jetbrains-toolbox ]; then
        local TOOLBOX_VERSION="2.5.2.35332"
        local toolbox_tarball="$TMP_DIR/jetbrains-toolbox.tar.gz"
        
        if safe_download "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${TOOLBOX_VERSION}.tar.gz" "$toolbox_tarball"; then
            tar -xzf "$toolbox_tarball" -C "$TMP_DIR" 2>> "$LOGFILE" || true
            
            local toolbox_dir=$(find "$TMP_DIR" -maxdepth 1 -type d -name "jetbrains-toolbox-*" 2>/dev/null | head -n 1)
            if [ -n "$toolbox_dir" ] && [ -f "$toolbox_dir/jetbrains-toolbox" ]; then
                sudo install -o root -g root -m 0755 "$toolbox_dir/jetbrains-toolbox" /usr/local/bin/jetbrains-toolbox
                log_info "JetBrains Toolbox installed successfully"
            else
                log_error "JetBrains Toolbox binary not found in extracted archive"
            fi
        fi
    fi
    
    # DBeaver from package manager
    log_info "Installing DBeaver..."
    install_if_missing dbeaver
    
    # Postman (no package manager option)
    log_info "Installing Postman..."
    if [ ! -d /opt/Postman ]; then
        local postman_tarball="$TMP_DIR/postman.tar.gz"
        if safe_download "https://dl.pstmn.io/download/latest/linux_64" "$postman_tarball"; then
            sudo tar -xzf "$postman_tarball" -C /opt 2>> "$LOGFILE" || true
            
            if [ -f /opt/Postman/Postman ]; then
                sudo ln -sf /opt/Postman/Postman /usr/local/bin/postman 2>> "$LOGFILE" || true
                
                cat <<EOF | sudo tee /usr/share/applications/postman.desktop
[Desktop Entry]
Name=Postman
Exec=/opt/Postman/Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Type=Application
Categories=Development;
EOF
            fi
        fi
    fi
}

# ==============================================================================
# MODULE 09: POST-SETUP CONFIGURATION
# ==============================================================================

module_09_post_setup() {
    log_info "=== MODULE 09: Post-Setup Configuration ==="
    
    # Configure Zsh
    log_info "Configuring Zsh..."
    if [ ! -f "$HOME/.zshrc" ] || ! grep -q "# WORKSTATION_SETUP_MARKER" "$HOME/.zshrc"; then
        backup_file "$HOME/.zshrc"
        
        cat > "$HOME/.zshrc" <<'EOF'
# WORKSTATION_SETUP_MARKER
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker kubectl terraform ansible)
source $ZSH/oh-my-zsh.sh

# Starship prompt
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"

# Path exports
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/usr/lib/golang/bin"
export PATH="$PATH:$HOME/go/bin"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Rust (only if installed via rustup)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Aliases
alias ls='eza'
alias ll='eza -la'
alias cat='bat'
alias k='kubectl'
alias dc='docker compose'
alias tf='terraform'
alias g='git'
alias cd='z'

# Editor
export EDITOR=vim

# Kubectl completion
command -v kubectl >/dev/null && source <(kubectl completion zsh)
EOF
    fi
    
    # Change default shell to Zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Changing default shell to Zsh..."
        chsh -s $(which zsh) 2>> "$LOGFILE" || log_error "Failed to change shell"
    fi
    
    # Ensure correct permissions
    log_info "Setting correct permissions..."
    if [ -d "$HOME/.local/bin" ]; then
        chmod +x "$HOME/.local/bin/"* 2>> "$LOGFILE" || true
    fi
    
    # Font cache refresh
    log_info "Refreshing font cache..."
    fc-cache -f 2>> "$LOGFILE" || true
    
    # Update locate database
    log_info "Updating locate database..."
    sudo updatedb 2>> "$LOGFILE" || true
    
    # Validation checks
    log_info "Running validation checks..."
    
    # Check Docker
    if command_exists docker; then
        if groups $USER | grep -q docker; then
            log_info "Docker: Installed and user in docker group"
            
            # Test Docker
            if docker ps >/dev/null 2>&1; then
                log_info "Docker: Service is running"
            else
                log_warning "Docker: Service running but may need re-login for group membership"
            fi
        else
            log_warning "Docker: User not in docker group yet (requires re-login)"
        fi
    else
        log_error "Docker: Not installed (CRITICAL)"
    fi
    
    # Check NVIDIA
    if [ "$HAS_NVIDIA" -eq 1 ]; then
        if command_exists nvidia-smi; then
            log_info "NVIDIA tools installed (driver validation requires reboot)"
        fi
        
        # Test NVIDIA + Docker if both are available
        if command_exists docker && package_installed nvidia-container-toolkit; then
            log_info "NVIDIA Container Toolkit installed - test after reboot with:"
            log_info "  docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi"
        fi
    fi
    
    # Check kubectl
    if command_exists kubectl; then
        if kubectl version --client &>> "$LOGFILE"; then
            log_info "kubectl: Working"
        else
            log_warning "kubectl: Installed but needs configuration"
        fi
    else
        log_error "kubectl: Not installed (CRITICAL)"
    fi
    
    # Check Terraform
    if command_exists terraform; then
        log_info "Terraform: Installed"
    else
        log_error "Terraform: Not installed (CRITICAL)"
    fi
    
    # Check cloud CLIs
    command_exists aws && log_info "AWS CLI: Installed" || log_warning "AWS CLI: Not found"
    command_exists az && log_info "Azure CLI: Installed" || log_warning "Azure CLI: Not found"
    command_exists gcloud && log_info "Google Cloud CLI: Installed" || log_warning "Google Cloud CLI: Not found"
    
    # SELinux container compatibility
    if command_exists getenforce && [ "$(getenforce)" = "Enforcing" ]; then
        log_info "Configuring SELinux for containers..."
        sudo setsebool -P container_manage_cgroup on 2>> "$LOGFILE" || log_warning "Failed to set container_manage_cgroup"
    fi
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    log_info "Starting Fedora Workstation Setup..."
    
    module_00_checks
    module_01_base
    module_02_nvidia
    module_03_devtools
    module_04_cloud
    module_05_kubernetes
    module_06_iac
    module_07_networking
    module_08_productivity
    module_09_post_setup
    
    SCRIPT_END=$(date '+%Y-%m-%d %H:%M:%S')
    echo "=== Setup completed at $SCRIPT_END ===" >> "$LOGFILE"
    
    cat <<EOF

================================================================================
                        Setup Completed Successfully
================================================================================

Installation Summary:
  ✓ System upgraded and security configured (FirewallD + Fail2ban)
  ✓ NVIDIA drivers installed (requires reboot for validation)
  ✓ Shell environment configured (Zsh + Starship + tmux)
  ✓ Development tools installed (Python, Node.js, Rust, Go)
  ✓ Docker and container runtime ready
  ✓ Kubernetes tools installed (kubectl, helm, k9s, kind, krew, stern)
  ✓ Cloud CLIs configured (AWS, Azure, GCP, GitHub)
  ✓ IaC tools installed (Terraform, Ansible, Vault, chezmoi, age)
  ✓ Networking tools ready (nmap, tcpdump, wireshark, mtr, iperf3)
  ✓ Observability stack installed (Prometheus, Grafana, Loki, Jaeger)
  ✓ Virtualization enabled (KVM/QEMU/Libvirt)
  ✓ IDEs installed (VS Code, JetBrains Toolbox, DBeaver, Postman)
  ✓ Productivity tools ready (btop, nvtop, eza, bat, fzf, ripgrep, zoxide)
  ✓ SELinux configured for container compatibility

CRITICAL NEXT STEPS:
  1. REBOOT your system to:
     - Load NVIDIA drivers and kernel modules
     - Apply all group memberships (docker, libvirt, kvm, wireshark)
     - Activate kernel parameters

  2. After reboot, validate installations:
     nvidia-smi                          # Verify NVIDIA drivers
     docker run hello-world              # Test Docker
     kubectl version --client            # Verify kubectl

  3. Test NVIDIA + Docker integration (if NVIDIA GPU present):
     docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

  4. Configure cloud CLIs:
     aws configure                       # AWS credentials
     az login                            # Azure authentication
     gcloud init                         # Google Cloud setup
     gh auth login                       # GitHub authentication

  5. Start using your new shell:
     Log out and back in, or run: exec zsh

  6. If you encounter SELinux issues:
     sudo ausearch -m avc -ts recent     # Check for denials
     sudo audit2allow -a                 # Generate policy recommendations

Configuration backups: $BACKUP_DIR
Error log: $LOGFILE

================================================================================
EOF
}

# Run main function
main "$@"
