#!/bin/bash

#############################################
# Fedora 43 Setup - Master Installer
# Description: Orchestrates all installation scripts
# Author: DevOps Setup Script
# Date: 2025
#############################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/.fedora-setup-logs"
MASTER_LOG="${LOG_DIR}/00-master-installer-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${MASTER_LOG}"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        Fedora 43 DevOps & Cloud Engineer Setup Suite          ║
║                                                               ║
║     Complete installation suite for Cloud, Network,           ║
║     DevOps, and Productivity tools                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}\n"
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

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root. Run as normal user with sudo privileges."
        exit 1
    fi
}

check_sudo() {
    if ! sudo -v; then
        print_error "Sudo privileges required but not available"
        exit 1
    fi
}

check_fedora_version() {
    if [[ -f /etc/fedora-release ]]; then
        local version=$(grep -oP 'release \K[0-9]+' /etc/fedora-release)
        if [[ "$version" -eq 43 ]]; then
            print_success "Fedora 43 detected"
            return 0
        else
            print_warning "This script is designed for Fedora 43, but detected version $version"
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && return 0 || exit 1
        fi
    else
        print_error "This doesn't appear to be a Fedora system"
        exit 1
    fi
}

# Available installation scripts
declare -A SCRIPTS=(
    ["01"]="System Foundation (NVIDIA, System Utils)"
    ["02"]="Terminal & Shell Environment"
    ["03"]="Containers & Orchestration"
    ["04"]="Cloud Provider CLIs"
    ["05"]="IaC & Configuration Management"
    ["06"]="Networking Tools"
    ["07"]="Development Tools"
    ["08"]="Monitoring & Observability"
    ["09"]="Security & Secrets Management"
    ["10"]="Productivity & Desktop Tools"
)

display_menu() {
    print_header "Installation Menu"
    
    echo "Available installation categories:"
    echo
    for key in $(echo "${!SCRIPTS[@]}" | tr ' ' '\n' | sort); do
        echo "  ${key}. ${SCRIPTS[$key]}"
    done
    echo
    echo "  00. Install ALL (Full Setup)"
    echo "  88. Install Custom Selection"
    echo "  99. Exit"
    echo
}

run_script() {
    local script_num=$1
    local script_file="${SCRIPT_DIR}/${script_num}-*.sh"
    
    # Find the actual script file
    local actual_script=$(ls $script_file 2>/dev/null | head -1)
    
    if [[ -f "$actual_script" ]]; then
        print_header "Running: ${SCRIPTS[$script_num]}"
        print_info "Script: $(basename $actual_script)"
        
        if bash "$actual_script" 2>&1 | tee -a "${MASTER_LOG}"; then
            print_success "Completed: ${SCRIPTS[$script_num]}"
            return 0
        else
            print_error "Failed: ${SCRIPTS[$script_num]}"
            return 1
        fi
    else
        print_error "Script not found: $script_file"
        return 1
    fi
}

install_all() {
    print_header "Full Installation - All Categories"
    print_warning "This will install ALL tools and may take significant time"
    read -p "Continue with full installation? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        return 1
    fi
    
    local failed_scripts=()
    
    for key in $(echo "${!SCRIPTS[@]}" | tr ' ' '\n' | sort); do
        if ! run_script "$key"; then
            failed_scripts+=("$key")
        fi
        echo
        sleep 2
    done
    
    if [ ${#failed_scripts[@]} -eq 0 ]; then
        print_success "All installations completed successfully!"
    else
        print_warning "Some installations failed: ${failed_scripts[*]}"
        print_info "Check the log file for details: ${MASTER_LOG}"
    fi
}

install_custom() {
    print_header "Custom Installation"
    echo "Enter script numbers separated by spaces (e.g., 01 03 07)"
    echo "Available: ${!SCRIPTS[@]}"
    echo
    read -p "Script numbers: " -r script_selection
    
    local failed_scripts=()
    
    for num in $script_selection; do
        # Pad single digit numbers
        local padded_num=$(printf "%02d" "$num" 2>/dev/null || echo "$num")
        
        if [[ -n "${SCRIPTS[$padded_num]}" ]]; then
            if ! run_script "$padded_num"; then
                failed_scripts+=("$padded_num")
            fi
            echo
            sleep 2
        else
            print_warning "Invalid script number: $num"
        fi
    done
    
    if [ ${#failed_scripts[@]} -eq 0 ]; then
        print_success "All selected installations completed successfully!"
    else
        print_warning "Some installations failed: ${failed_scripts[*]}"
        print_info "Check the log file for details: ${MASTER_LOG}"
    fi
}

create_summary_report() {
    print_header "Installation Summary Report"
    
    local report_file="${HOME}/.fedora-setup-summary.txt"
    
    cat > "$report_file" <<EOF
================================================================================
Fedora 43 DevOps & Cloud Engineer Setup
Installation Summary
Generated: $(date)
================================================================================

Log Files Location: ${LOG_DIR}
Master Log: ${MASTER_LOG}

Installed Categories:
EOF
    
    for key in $(echo "${!SCRIPTS[@]}" | tr ' ' '\n' | sort); do
        local script_log="${LOG_DIR}/${key}-*.log"
        if ls $script_log &>/dev/null; then
            echo "  ✓ ${SCRIPTS[$key]}" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" <<EOF

Important Next Steps:
================================================================================
1. Restart your system for all changes to take effect
2. Log out and back in for group memberships to activate
3. Configure cloud provider credentials (AWS, Azure, GCP)
4. Setup your preferred shell (zsh recommended)
5. Configure your text editor/IDE
6. Review all logs in: ${LOG_DIR}

Useful Commands:
================================================================================
- Check NVIDIA driver: nvidia-smi
- Test Docker: docker ps
- Test Kubernetes: kubectl version --client
- Test cloud CLIs: aws --version, az --version, gcloud --version
- Access Cockpit: https://localhost:9090

Configuration Files:
================================================================================
- Shell configs: ~/.zshrc, ~/.bashrc
- Ansible: ~/.ansible/
- Kubernetes: ~/.kube/config
- Cloud CLIs: ~/.aws/, ~/.azure/, ~/.config/gcloud/

Support & Documentation:
================================================================================
For issues or questions, review the individual script logs in ${LOG_DIR}
Each script creates detailed logs of all operations performed.

================================================================================
EOF
    
    cat "$report_file"
    print_success "Summary report saved to: $report_file"
}

check_disk_space() {
    local required_gb=20
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $available_gb -lt $required_gb ]]; then
        print_warning "Low disk space: ${available_gb}GB available (${required_gb}GB recommended)"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    else
        print_success "Sufficient disk space: ${available_gb}GB available"
    fi
}

main() {
    print_banner
    
    print_info "Master installer log: ${MASTER_LOG}"
    
    check_root
    check_sudo
    check_fedora_version
    check_disk_space
    
    while true; do
        display_menu
        read -p "Select option: " choice
        
        case $choice in
            00)
                install_all
                create_summary_report
                break
                ;;
            88)
                install_custom
                create_summary_report
                break
                ;;
            99)
                print_info "Exiting installer"
                exit 0
                ;;
            *)
                # Pad single digit
                local padded=$(printf "%02d" "$choice" 2>/dev/null || echo "$choice")
                if [[ -n "${SCRIPTS[$padded]}" ]]; then
                    run_script "$padded"
                    echo
                    read -p "Press enter to continue..."
                else
                    print_error "Invalid option: $choice"
                    sleep 2
                fi
                ;;
        esac
    done
    
    print_header "Installation Complete!"
    print_success "All installations have finished"
    print_info "Please review the summary report and logs"
    print_warning "IMPORTANT: Restart your system for all changes to take effect"
}

# Run main function
main "$@"
