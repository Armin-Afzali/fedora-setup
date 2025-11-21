#!/usr/bin/env bash

# ==============================================================================
# Module 09: Post-Setup Configuration
# Final configuration, validation, and system optimization
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

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
    
    log_info "Post-setup configuration completed"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_09_post_setup
fi
