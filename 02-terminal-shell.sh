#!/bin/bash

#############################################
# Fedora 43 Setup - Terminal & Shell Environment
# Description: Terminal emulators, shell enhancements, CLI tools
# Author: DevOps Setup Script
# Date: 2025
#############################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging setup
LOG_DIR="${HOME}/.fedora-setup-logs"
LOG_FILE="${LOG_DIR}/02-terminal-shell-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

# Log function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Pretty print functions
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

# Error handler
error_exit() {
    print_error "$1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should NOT be run as root. Run as normal user with sudo privileges."
    fi
}

# Check sudo access
check_sudo() {
    if ! sudo -v; then
        error_exit "Sudo privileges required but not available"
    fi
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
}

# Install terminal emulators
install_terminals() {
    print_header "Installing Terminal Emulators"
    
    local packages=(
        alacritty
        kitty
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Terminal emulators installed"
}

# Install multiplexers
install_multiplexers() {
    print_header "Installing Terminal Multiplexers"
    
    local packages=(
        tmux
        screen
        byobu
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Terminal multiplexers installed"
}

# Install shells
install_shells() {
    print_header "Installing Alternative Shells"
    
    local packages=(
        zsh
        fish
        util-linux-user
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Alternative shells installed"
}

# Install modern CLI tools
install_modern_cli() {
    print_header "Installing Modern CLI Tools"
    
    local packages=(
        bat
        fd-find
        ripgrep
        fzf
        zoxide
        thefuck
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Modern CLI tools installed"
}

# Install tools from cargo (Rust)
install_rust_tools() {
    print_header "Installing Rust-based Tools"
    
    # Check if cargo is available
    if ! command -v cargo &>/dev/null; then
        print_info "Installing Rust and Cargo..."
        sudo dnf5 install -y rust cargo 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    # Tools to install via cargo
    local cargo_tools=(
        exa
        starship
        mcfly
    )
    
    for tool in "${cargo_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            print_info "Installing $tool via cargo..."
            cargo install "$tool" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $tool"
        else
            print_info "$tool already installed"
        fi
    done
    
    print_success "Rust-based tools installed"
}

# Install Oh My Zsh
install_oh_my_zsh() {
    print_header "Installing Oh My Zsh"
    
    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        print_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Oh My Zsh"
        print_success "Oh My Zsh installed"
    else
        print_info "Oh My Zsh already installed"
    fi
    
    # Install popular plugins
    local zsh_custom="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
    
    # zsh-autosuggestions
    if [[ ! -d "${zsh_custom}/plugins/zsh-autosuggestions" ]]; then
        print_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "${zsh_custom}/plugins/zsh-autosuggestions" 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    # zsh-syntax-highlighting
    if [[ ! -d "${zsh_custom}/plugins/zsh-syntax-highlighting" ]]; then
        print_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${zsh_custom}/plugins/zsh-syntax-highlighting" 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    print_success "Oh My Zsh plugins installed"
}

# Install Starship prompt
configure_starship() {
    print_header "Configuring Starship Prompt"
    
    if command -v starship &>/dev/null; then
        # Create default config if doesn't exist
        if [[ ! -f "${HOME}/.config/starship.toml" ]]; then
            print_info "Creating Starship configuration..."
            mkdir -p "${HOME}/.config"
            starship preset nerd-font-symbols -o "${HOME}/.config/starship.toml" 2>&1 | tee -a "${LOG_FILE}"
            print_success "Starship configured"
        else
            print_info "Starship already configured"
        fi
    fi
}

# Install additional utilities
install_utilities() {
    print_header "Installing Additional CLI Utilities"
    
    # Install tldr via npm if available, otherwise via dnf
    if command -v npm &>/dev/null; then
        if ! command -v tldr &>/dev/null; then
            print_info "Installing tldr via npm..."
            npm install -g tldr 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install tldr"
        fi
    else
        if ! rpm -q tldr &>/dev/null; then
            print_info "Installing tldr-py..."
            sudo dnf5 install -y python3-pip 2>&1 | tee -a "${LOG_FILE}"
            pip3 install --user tldr 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install tldr"
        fi
    fi
    
    print_success "Additional utilities installed"
}

# Create shell configurations
create_shell_configs() {
    print_header "Creating Shell Configuration Hints"
    
    local config_file="${HOME}/.fedora-setup-shell-config.txt"
    
    cat > "$config_file" <<'EOF'
# Shell Configuration Suggestions
# Add these to your .zshrc or .bashrc as needed

# Starship prompt (add to end of .zshrc or .bashrc)
eval "$(starship init zsh)"  # for zsh
# eval "$(starship init bash)"  # for bash

# Zoxide (smarter cd)
eval "$(zoxide init zsh)"  # for zsh
# eval "$(zoxide init bash)"  # for bash

# McFly (shell history)
eval "$(mcfly init zsh)"  # for zsh
# eval "$(mcfly init bash)"  # for bash

# FZF key bindings
[ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh

# Aliases for modern tools
alias ls='exa'
alias ll='exa -l'
alias la='exa -la'
alias cat='bat'
alias find='fd'
alias grep='rg'

# Oh My Zsh plugins recommendation
# Edit ~/.zshrc and update plugins line:
# plugins=(git docker kubectl terraform ansible zsh-autosuggestions zsh-syntax-highlighting)

EOF
    
    print_success "Shell configuration hints created at: $config_file"
    print_info "Review the file and apply configurations to your shell RC file"
}

# Main execution
main() {
    print_header "Fedora 43 Terminal & Shell Environment Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    install_terminals
    install_multiplexers
    install_shells
    install_modern_cli
    install_rust_tools
    install_oh_my_zsh
    configure_starship
    install_utilities
    create_shell_configs
    
    print_header "Installation Summary"
    print_success "Terminal & Shell environment setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nNext Steps:"
    echo "1. Review shell configuration hints: ${HOME}/.fedora-setup-shell-config.txt"
    echo "2. Change your default shell (optional): chsh -s /usr/bin/zsh"
    echo "3. Restart your terminal or source your shell config"
    echo "4. Configure Oh My Zsh plugins in ~/.zshrc"
    
    print_info "\nReview the log file for any warnings or errors"
}

# Run main function
main "$@"
