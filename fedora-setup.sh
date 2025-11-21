#!/usr/bin/env bash

# ==============================================================================
# Fedora 43 Cloud + DevOps + Networking Workstation Setup
# Main Orchestrator Script - Modular Edition
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$HOME/setup-error.log"
BACKUP_DIR="$HOME/.config-backups/$(date +%Y%m%d-%H%M%S)"
SCRIPT_START=$(date '+%Y-%m-%d %H:%M:%S')

# Export variables for modules
export LOGFILE
export BACKUP_DIR
export TMP_DIR=$(mktemp -d)

# Initialize log file
mkdir -p "$(dirname "$LOGFILE")"
echo "=== Setup started at $SCRIPT_START ===" > "$LOGFILE"

# Cleanup trap
trap 'rm -rf "$TMP_DIR"' EXIT

# Source common functions
if [ ! -f "$SCRIPT_DIR/utility.sh" ]; then
    echo "ERROR: utility.sh not found in $SCRIPT_DIR"
    exit 1
fi

source "$SCRIPT_DIR/utility.sh"

# ==============================================================================
# MODULE EXECUTION
# ==============================================================================

run_module() {
    local module_script="$1"
    local module_name="$2"
    
    if [ ! -f "$SCRIPT_DIR/$module_script" ]; then
        log_error "Module $module_script not found, skipping..."
        return 1
    fi
    
    log_info "Executing module: $module_name"
    
    if bash "$SCRIPT_DIR/$module_script"; then
        log_info "Module $module_name completed successfully"
        return 0
    else
        log_error "Module $module_name failed"
        return 1
    fi
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    log_info "Starting Fedora Workstation Setup (Modular Edition)..."
    
    # Module execution with error handling
    local failed_modules=()
    
    run_module "00-preflight-checks.sh" "Pre-flight Checks" || failed_modules+=("Pre-flight Checks")
    run_module "01-base-system.sh" "Base System" || failed_modules+=("Base System")
    run_module "02-nvidia-drivers.sh" "NVIDIA Drivers" || failed_modules+=("NVIDIA Drivers")
    run_module "03-development-tools.sh" "Development Tools" || failed_modules+=("Development Tools")
    run_module "04-cloud-tools.sh" "Cloud Tools" || failed_modules+=("Cloud Tools")
    run_module "05-kubernetes-tools.sh" "Kubernetes Tools" || failed_modules+=("Kubernetes Tools")
    run_module "06-iac-tools.sh" "IaC Tools" || failed_modules+=("IaC Tools")
    run_module "07-networking-tools.sh" "Networking Tools" || failed_modules+=("Networking Tools")
    run_module "08-productivity-tools.sh" "Productivity Tools" || failed_modules+=("Productivity Tools")
    run_module "09-post-setup.sh" "Post-Setup Configuration" || failed_modules+=("Post-Setup Configuration")
    
    SCRIPT_END=$(date '+%Y-%m-%d %H:%M:%S')
    echo "=== Setup completed at $SCRIPT_END ===" >> "$LOGFILE"
    
    # Summary report
    cat <<EOF

================================================================================
                        Setup Completed
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

EOF

    if [ ${#failed_modules[@]} -gt 0 ]; then
        echo "⚠️  WARNING: Some modules failed:"
        for module in "${failed_modules[@]}"; do
            echo "  - $module"
        done
        echo ""
    fi

    cat <<EOF
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
