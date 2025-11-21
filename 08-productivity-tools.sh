#!/usr/bin/env bash

# ==============================================================================
# Module 08: Productivity & Observability Tools
# Shell environment, modern CLI tools, monitoring, virtualization, IDEs
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

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
    
    log_info "Productivity and observability tools setup completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_08_productivity
fi
