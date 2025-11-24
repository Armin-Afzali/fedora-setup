#!/bin/bash

#############################################
# Fedora 43 Setup - Development Tools
# Description: Languages, runtimes, editors, IDEs, code quality tools
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
LOG_FILE="${LOG_DIR}/07-development-tools-$(date +%Y%m%d-%H%M%S).log"
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

# Install Python ecosystem
install_python() {
    print_header "Installing Python Ecosystem"
    
    local packages=(
        python3
        python3-pip
        python3-devel
        python3-virtualenv
        python3-wheel
        python3-setuptools
        pipx
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install poetry via pipx
    if ! command -v poetry &>/dev/null; then
        print_info "Installing Poetry via pipx..."
        pipx install poetry 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install poetry"
    fi
    
    # Ensure pipx binaries are in PATH
    pipx ensurepath 2>&1 | tee -a "${LOG_FILE}"
    
    print_success "Python ecosystem installed"
}

# Install Go
install_go() {
    print_header "Installing Go"
    
    if ! rpm -q golang &>/dev/null; then
        print_info "Installing Go..."
        sudo dnf5 install -y golang 2>&1 | tee -a "${LOG_FILE}"
        print_success "Go installed"
    else
        print_info "Go already installed: $(go version)"
    fi
}

# Install Node.js
install_nodejs() {
    print_header "Installing Node.js"
    
    local packages=(
        nodejs
        npm
        yarn
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install nvm for version management
    if [[ ! -d "${HOME}/.nvm" ]]; then
        print_info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash 2>&1 | tee -a "${LOG_FILE}"
        print_success "nvm installed"
        print_info "Add to shell rc: source ~/.nvm/nvm.sh"
    else
        print_info "nvm already installed"
    fi
    
    print_success "Node.js ecosystem installed"
}

# Install Rust
install_rust() {
    print_header "Installing Rust"
    
    if ! command -v rustc &>/dev/null; then
        print_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | tee -a "${LOG_FILE}"
        source "$HOME/.cargo/env"
        print_success "Rust installed"
        print_info "Add to shell rc: source \$HOME/.cargo/env"
    else
        print_info "Rust already installed: $(rustc --version)"
    fi
}

# Install Ruby
install_ruby() {
    print_header "Installing Ruby"
    
    local packages=(
        ruby
        ruby-devel
        rubygems
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Ruby installed"
}

# Install Java
install_java() {
    print_header "Installing Java"
    
    local packages=(
        java-latest-openjdk
        java-latest-openjdk-devel
        maven
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install Gradle
    if ! command -v gradle &>/dev/null; then
        print_info "Installing Gradle..."
        sudo dnf5 install -y gradle 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install Gradle"
    fi
    
    print_success "Java ecosystem installed"
}

# Install .NET
install_dotnet() {
    print_header "Installing .NET SDK"
    
    if ! command -v dotnet &>/dev/null; then
        print_info "Installing .NET SDK..."
        sudo dnf5 install -y dotnet-sdk-8.0 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install .NET SDK"
        print_success ".NET SDK installed"
    else
        print_info ".NET SDK already installed: $(dotnet --version)"
    fi
}

# Install text editors
install_editors() {
    print_header "Installing Text Editors"
    
    # Neovim
    if ! command -v nvim &>/dev/null; then
        print_info "Installing Neovim..."
        sudo dnf5 install -y neovim 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    # Vim
    if ! rpm -q vim-enhanced &>/dev/null; then
        print_info "Installing Vim..."
        sudo dnf5 install -y vim-enhanced 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    # Emacs
    read -p "Install Emacs? (y/n) " -n 1 -r install_emacs
    echo
    if [[ $install_emacs =~ ^[Yy]$ ]]; then
        if ! rpm -q emacs &>/dev/null; then
            print_info "Installing Emacs..."
            sudo dnf5 install -y emacs 2>&1 | tee -a "${LOG_FILE}"
        fi
    fi
    
    print_success "Text editors installed"
}

# Install VSCode
install_vscode() {
    print_header "Installing Visual Studio Code"
    
    if ! command -v code &>/dev/null; then
        print_info "Adding Microsoft VSCode repository..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>&1 | tee -a "${LOG_FILE}"
        
        echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo
        
        print_info "Installing VSCode..."
        sudo dnf5 install -y code 2>&1 | tee -a "${LOG_FILE}"
        print_success "VSCode installed"
    else
        print_info "VSCode already installed"
    fi
}

# Install code quality tools
install_code_quality() {
    print_header "Installing Code Quality and Linting Tools"
    
    local packages=(
        shellcheck
        yamllint
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install hadolint (Dockerfile linter)
    if ! command -v hadolint &>/dev/null; then
        print_info "Installing hadolint..."
        sudo curl -L "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/hadolint
    fi
    
    # Python linters
    print_info "Installing Python linters..."
    pipx install pylint 2>&1 | tee -a "${LOG_FILE}" || true
    pipx install flake8 2>&1 | tee -a "${LOG_FILE}" || true
    pipx install black 2>&1 | tee -a "${LOG_FILE}" || true
    
    # Go linters
    if command -v go &>/dev/null; then
        if ! command -v golangci-lint &>/dev/null; then
            print_info "Installing golangci-lint..."
            curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "$(go env GOPATH)/bin" 2>&1 | tee -a "${LOG_FILE}"
        fi
    fi
    
    # Install markdownlint
    if command -v npm &>/dev/null; then
        print_info "Installing markdownlint..."
        npm install -g markdownlint-cli 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install markdownlint"
    fi
    
    print_success "Code quality tools installed"
}

# Install API development tools
install_api_tools() {
    print_header "Installing API Development Tools"
    
    local packages=(
        httpie
        curl
        wget
        jq
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    # Install yq
    if ! command -v yq &>/dev/null; then
        print_info "Installing yq..."
        local version=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_amd64" -o /usr/local/bin/yq 2>&1 | tee -a "${LOG_FILE}"
        sudo chmod +x /usr/local/bin/yq
    fi
    
    # Install grpcurl
    if ! command -v grpcurl &>/dev/null; then
        print_info "Installing grpcurl..."
        go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install grpcurl"
    fi
    
    print_success "API development tools installed"
}

# Install build tools
install_build_tools() {
    print_header "Installing Build Tools"
    
    local packages=(
        make
        cmake
        gcc
        gcc-c++
        gdb
        valgrind
        strace
        ltrace
        perf
        autoconf
        automake
        libtool
    )
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            print_info "Installing $pkg..."
            sudo dnf5 install -y "$pkg" 2>&1 | tee -a "${LOG_FILE}" || print_warning "Failed to install $pkg"
        else
            print_info "$pkg already installed"
        fi
    done
    
    print_success "Build tools installed"
}

# Main execution
main() {
    print_header "Fedora 43 Development Tools Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    install_build_tools
    install_python
    install_go
    install_nodejs
    install_rust
    install_ruby
    install_java
    
    read -p "Install .NET SDK? (y/n) " -n 1 -r install_dotnet_sdk
    echo
    [[ $install_dotnet_sdk =~ ^[Yy]$ ]] && install_dotnet
    
    install_editors
    
    read -p "Install Visual Studio Code? (y/n) " -n 1 -r install_vs_code
    echo
    [[ $install_vs_code =~ ^[Yy]$ ]] && install_vscode
    
    install_code_quality
    install_api_tools
    
    print_header "Installation Summary"
    print_success "Development Tools setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Languages & Runtimes:"
    echo "  - Python (with poetry, virtualenv)"
    echo "  - Go"
    echo "  - Node.js (with npm, yarn, nvm)"
    echo "  - Rust"
    echo "  - Ruby"
    echo "  - Java (with Maven, Gradle)"
    [[ $install_dotnet_sdk =~ ^[Yy]$ ]] && echo "  - .NET SDK"
    
    print_info "\nInstalled Editors:"
    echo "  - Neovim"
    echo "  - Vim"
    [[ $install_emacs =~ ^[Yy]$ ]] && echo "  - Emacs"
    [[ $install_vs_code =~ ^[Yy]$ ]] && echo "  - Visual Studio Code"
    
    print_info "\nInstalled Tools:"
    echo "  - Code quality: shellcheck, yamllint, hadolint, pylint, flake8, black"
    echo "  - API tools: httpie, curl, jq, yq, grpcurl"
    echo "  - Build tools: make, cmake, gcc, gdb, valgrind"
    
    print_info "\nNext Steps:"
    echo "1. Restart your terminal or source your shell rc"
    echo "2. Configure your editors (neovim, vscode)"
    echo "3. Test language installations:"
    echo "   - python3 --version"
    echo "   - go version"
    echo "   - node --version"
    echo "   - rustc --version"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
