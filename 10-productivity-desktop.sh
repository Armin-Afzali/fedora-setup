#!/bin/bash

#############################################
# Fedora 43 Setup - Productivity & Desktop Tools
# Description: Browsers, communication, screenshots, fonts, themes
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
LOG_FILE="${LOG_DIR}/10-productivity-desktop-$(date +%Y%m%d-%H%M%S).log"
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

# Enable Flatpak
enable_flatpak() {
    print_header "Enabling Flatpak"
    
    if ! command -v flatpak &>/dev/null; then
        print_info "Installing Flatpak..."
        sudo dnf5 install -y flatpak 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    print_info "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Flatpak enabled"
}

# Install browsers
install_browsers() {
    print_header "Installing Web Browsers"
    
    # Firefox (should be pre-installed)
    if ! rpm -q firefox &>/dev/null; then
        print_info "Installing Firefox..."
        sudo dnf5 install -y firefox 2>&1 | tee -a "${LOG_FILE}"
    else
        print_info "Firefox already installed"
    fi
    
    # Google Chrome
    read -p "Install Google Chrome? (y/n) " -n 1 -r install_chrome
    echo
    if [[ $install_chrome =~ ^[Yy]$ ]]; then
        if ! command -v google-chrome &>/dev/null; then
            print_info "Adding Google Chrome repository..."
            cat <<EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
            
            print_info "Installing Google Chrome..."
            sudo dnf5 install -y google-chrome-stable 2>&1 | tee -a "${LOG_FILE}"
            print_success "Google Chrome installed"
        else
            print_info "Google Chrome already installed"
        fi
    fi
    
    # Chromium
    read -p "Install Chromium? (y/n) " -n 1 -r install_chromium
    echo
    if [[ $install_chromium =~ ^[Yy]$ ]]; then
        if ! rpm -q chromium &>/dev/null; then
            print_info "Installing Chromium..."
            sudo dnf5 install -y chromium 2>&1 | tee -a "${LOG_FILE}"
            print_success "Chromium installed"
        else
            print_info "Chromium already installed"
        fi
    fi
}

# Install screenshot and recording tools
install_screenshot_tools() {
    print_header "Installing Screenshot and Recording Tools"
    
    local packages=(
        flameshot
        obs-studio
        kazam
        simplescreenrecorder
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Peek (GIF recorder)
    if ! flatpak list | grep -q com.uploadedlobster.peek; then
        print_info "Installing Peek via Flatpak..."
        flatpak install -y flathub com.uploadedlobster.peek 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Peek"
    fi
    
    print_success "Screenshot and recording tools installed"
}

# Install fonts
install_fonts() {
    print_header "Installing Fonts"
    
    local packages=(
        fontawesome-fonts
        google-noto-fonts-common
        google-noto-sans-fonts
        google-noto-serif-fonts
        google-noto-emoji-fonts
        fira-code-fonts
        jetbrains-mono-fonts
        liberation-fonts
        font-manager
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Microsoft fonts (optional)
    read -p "Install Microsoft TrueType core fonts? (y/n) " -n 1 -r install_msfonts
    echo
    if [[ $install_msfonts =~ ^[Yy]$ ]]; then
        if ! rpm -q msttcore-fonts-installer &>/dev/null; then
            print_info "Installing Microsoft fonts..."
            sudo dnf5 install -y msttcore-fonts-installer 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install MS fonts"
        fi
    fi
    
    # Rebuild font cache
    print_info "Rebuilding font cache..."
    fc-cache -f -v 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Fonts installed"
}

# Install themes and icons
install_themes() {
    print_header "Installing Themes and Icons"
    
    # Papirus icon theme
    if ! rpm -q papirus-icon-theme &>/dev/null; then
        print_info "Installing Papirus icon theme..."
        sudo dnf5 install -y papirus-icon-theme 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    # Arc theme
    if ! rpm -q arc-theme &>/dev/null; then
        print_info "Installing Arc theme..."
        sudo dnf5 install -y arc-theme 2>&1 | tee -a "${LOG_FILE}" || print_warning "Arc theme not available in repos"
    fi
    
    print_success "Themes and icons installed"
}

# Install GNOME extensions tools (if using GNOME)
install_gnome_tools() {
    if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
        print_header "Installing GNOME Tools"
        
        local packages=(
            gnome-tweaks
            gnome-extensions-app
            dconf-editor
        )
        
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then
                print_info "Installing $pkg..."
                sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
            else
                print_info "$pkg already installed"
            fi
        done
        
        print_success "GNOME tools installed"
    else
        print_info "Not using GNOME, skipping GNOME-specific tools"
    fi
}

# Install Cockpit
install_cockpit() {
    print_header "Installing Cockpit System Manager"
    
    local packages=(
        cockpit
        cockpit-podman
        cockpit-machines
        cockpit-networkmanager
        cockpit-storaged
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Enable and start cockpit
    print_info "Enabling Cockpit..."
    sudo systemctl enable --now cockpit.socket 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Cockpit installed and enabled"
    print_info "Access Cockpit at: https://localhost:9090"
}

# Install communication tools via Flatpak
install_communication_flatpak() {
    print_header "Installing Communication Tools"
    
    local apps=(
        "com.slack.Slack:Slack"
        "com.discordapp.Discord:Discord"
        "us.zoom.Zoom:Zoom"
    )
    
    for app_info in "${apps[@]}"; do
        IFS=':' read -r app_id app_name <<< "$app_info"
        
        read -p "Install $app_name via Flatpak? (y/n) " -n 1 -r install_app
        echo
        
        if [[ $install_app =~ ^[Yy]$ ]]; then
            if ! flatpak list | grep -q "$app_id"; then
                print_info "Installing $app_name..."
                flatpak install -y flathub "$app_id" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $app_name"
            else
                print_info "$app_name already installed"
            fi
        fi
    done
}

# Install documentation tools
install_documentation_tools() {
    print_header "Installing Documentation Tools"
    
    local packages=(
        pandoc
        graphviz
        plantuml
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Hugo (static site generator)
    if ! command -v hugo &>/dev/null; then
        print_info "Installing Hugo..."
        sudo dnf5 install -y hugo 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Hugo"
    fi
    
    print_success "Documentation tools installed"
}

# Install misc utilities
install_misc_utilities() {
    print_header "Installing Miscellaneous Utilities"
    
    local packages=(
        tree
        ncdu
        parallel
        bc
        units
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Modern alternatives (some via cargo/go)
    if command -v cargo &>/dev/null; then
        local rust_tools=(
            duf
            dust
            procs
            bottom
        )
        
        for tool in "${rust_tools[@]}"; do
            if ! command -v "$tool" &>/dev/null; then
                print_info "Installing $tool via cargo..."
                cargo install "$tool" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $tool"
            fi
        done
    fi
    
    print_success "Miscellaneous utilities installed"
}

# Main execution
main() {
    print_header "Fedora 43 Productivity & Desktop Tools Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    enable_flatpak
    install_browsers
    install_screenshot_tools
    install_fonts
    install_themes
    install_gnome_tools
    install_cockpit
    install_communication_flatpak
    install_documentation_tools
    install_misc_utilities
    
    print_header "Installation Summary"
    print_success "Productivity & Desktop Tools setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    echo "  - Browsers: Firefox, Chrome/Chromium (optional)"
    echo "  - Screenshots: Flameshot, OBS Studio, Peek"
    echo "  - Fonts: Noto, Fira Code, JetBrains Mono, FontAwesome"
    echo "  - Themes: Papirus icons, Arc theme"
    echo "  - System: Cockpit web interface"
    echo "  - Communication: Slack, Discord, Zoom (optional)"
    echo "  - Documentation: Pandoc, GraphViz, Hugo"
    
    print_info "\nNext Steps:"
    echo "1. Restart for Flatpak apps to appear in menu"
    echo "2. Access Cockpit: https://localhost:9090"
    echo "3. Configure Flameshot hotkeys in system settings"
    echo "4. Customize GNOME with gnome-tweaks (if using GNOME)"
    echo "5. Browse Flathub for more apps: https://flathub.org"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
