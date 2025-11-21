# Fedora Workstation Setup - Modular Edition

A decoupled, modular approach to setting up a complete Cloud + DevOps + Networking workstation on Fedora 43.

## 📁 Project Structure

```
.
├── utility.sh          # Shared utilities and logging functions
├── setup-workstation.sh         # Main orchestrator script
├── 00-preflight-checks.sh       # System validation and requirements
├── 01-base-system.sh            # Base packages, repos, and security
├── 02-nvidia-drivers.sh         # NVIDIA GPU drivers (optional)
├── 03-development-tools.sh      # Programming languages and build tools
├── 04-cloud-tools.sh            # Docker, AWS, Azure, GCP, Tailscale
├── 05-kubernetes-tools.sh       # kubectl, helm, k9s, kind, stern
├── 06-iac-tools.sh              # Terraform, Ansible, Vault, chezmoi
├── 07-networking-tools.sh       # Network diagnostics and monitoring
├── 08-productivity-tools.sh     # Shell, IDEs, observability, virtualization
└── 09-post-setup.sh             # Final configuration and validation
```

## 🚀 Quick Start

### Full Installation (Recommended)

Run all modules in sequence:

```bash
chmod +x *.sh
./setup-workstation.sh
```

### Selective Installation

Run only the modules you need:

```bash
# Prerequisites
./00-preflight-checks.sh
./01-base-system.sh

# Choose what you need
./03-development-tools.sh    # Python, Node.js, Rust, Go
./04-cloud-tools.sh          # Docker + Cloud CLIs
./05-kubernetes-tools.sh     # K8s ecosystem
./06-iac-tools.sh            # Terraform, Ansible
./08-productivity-tools.sh   # Zsh, IDEs, monitoring

# Finalize
./09-post-setup.sh
```

## 📋 Module Details

### 00 - Pre-flight Checks
- Validates sudo access
- Checks internet connectivity
- Verifies disk space (10GB minimum)
- Detects Fedora version
- Identifies NVIDIA GPU presence
- Checks SELinux status

### 01 - Base System
- System updates and upgrades
- RPM Fusion repositories
- FirewallD configuration
- Fail2ban security
- Essential CLI utilities (vim, git, curl, jq, etc.)

### 02 - NVIDIA Drivers
- Detects and installs NVIDIA proprietary drivers
- Configures kernel parameters
- Builds NVIDIA kernel modules
- Sets up CUDA support
- **Skipped automatically** if no GPU detected

### 03 - Development Tools
- Build tools (gcc, clang, cmake)
- Python 3 + pipx + poetry
- Node.js + npm + pnpm
- Rust + Cargo
- Go toolchain
- Development headers

### 04 - Cloud Tools
- Docker CE + Compose
- NVIDIA Container Toolkit (if GPU present)
- AWS CLI v2
- Azure CLI
- Google Cloud CLI
- GitHub CLI
- Tailscale VPN

### 05 - Kubernetes Tools
- kubectl (v1.31)
- Helm
- k9s (cluster management UI)
- kind (local clusters)
- krew (plugin manager)
- stern (log tailing)

### 06 - IaC Tools
- Terraform
- HashiCorp Vault
- Ansible + Ansible Core
- chezmoi (dotfile management)
- age (encryption)

### 07 - Networking Tools
- nmap, tcpdump, wireshark
- mtr, iperf3, socat
- WireGuard tools
- DNS utilities (bind-utils)
- nftables, traceroute

### 08 - Productivity & Observability
- **Shell**: Zsh + Oh My Zsh + Starship + plugins
- **Modern CLI**: btop, fzf, ripgrep, eza, bat, zoxide
- **Monitoring**: Prometheus, Grafana, Loki, Promtail, Jaeger, nvtop
- **Virtualization**: KVM/QEMU + libvirt + virt-manager
- **IDEs**: VS Code, JetBrains Toolbox, DBeaver, Postman
- **Terminal**: tmux with custom configuration

### 09 - Post-Setup
- Configures Zsh with custom settings
- Sets up shell aliases and environment
- Validates all installations
- Configures SELinux for containers
- Generates summary report

## 🛠️ Advanced Usage

### Running Individual Modules

Each module can be executed independently:

```bash
# Only install Docker and cloud CLIs
source utility.sh
./04-cloud-tools.sh

# Only set up Kubernetes tools
source utility.sh
./05-kubernetes-tools.sh
```

### Skipping Modules

Modify `setup-workstation.sh` and comment out unwanted modules:

```bash
# run_module "08-productivity-tools.sh" "Productivity Tools"
```

### Custom Configuration

Set environment variables before running:

```bash
export LOGFILE="/custom/path/setup.log"
export BACKUP_DIR="/custom/backups"
./setup-workstation.sh
```

## 📝 Logging and Debugging

- **Default log location**: `~/setup-error.log`
- **Backup directory**: `~/.config-backups/YYYYMMDD-HHMMSS/`
- **Verbose output**: All modules log to console and file

Check logs for errors:
```bash
tail -f ~/setup-error.log
grep ERROR ~/setup-error.log
```

## ⚠️ Important Notes

### Reboot Required
After installation, **reboot your system** to:
- Load NVIDIA kernel modules
- Activate group memberships (docker, libvirt, kvm, wireshark)
- Apply kernel parameters

### Group Memberships
The following groups require re-login or reboot:
- `docker` - Docker daemon access
- `libvirt` - Virtual machine management
- `kvm` - KVM acceleration
- `wireshark` - Network packet capture

### SELinux Considerations
If SELinux is enforcing, you may need to:
```bash
# Allow container cgroup management
sudo setsebool -P container_manage_cgroup on

# Check for denials
sudo ausearch -m avc -ts recent

# Generate policy if needed
sudo audit2allow -a
```

### NVIDIA Validation
After reboot, verify NVIDIA setup:
```bash
# Check driver
nvidia-smi

# Test with Docker
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

## 🔧 Dependencies

### Required
- Fedora 39+ (optimized for Fedora 43)
- Sudo privileges
- Internet connectivity
- 10GB free disk space

### Optional
- NVIDIA GPU (for module 02)
- GUI environment (for some IDEs and tools)

## 📦 What Gets Installed

**Total packages**: 150+

Key installations:
- **Languages**: Python, Node.js, Rust, Go
- **Containers**: Docker, containerd, NVIDIA runtime
- **Kubernetes**: kubectl, helm, k9s, kind, krew, stern
- **Cloud**: AWS CLI, Azure CLI, gcloud, gh
- **IaC**: Terraform, Ansible, Vault, chezmoi
- **Monitoring**: Prometheus, Grafana, Loki, Jaeger
- **Networking**: nmap, wireshark, tcpdump, mtr, iperf3
- **Virtualization**: KVM, QEMU, libvirt, virt-manager
- **IDEs**: VS Code, JetBrains Toolbox, DBeaver, Postman
- **Shell**: Zsh, Oh My Zsh, Starship, tmux
- **Utilities**: btop, nvtop, fzf, ripgrep, eza, bat, zoxide

## 🤝 Contributing

To add a new module:

1. Create `XX-module-name.sh` following the template:
```bash
#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utility.sh"

module_XX_name() {
    log_info "=== MODULE XX: Name ==="
    # Your installation logic
}

if [ "${BASH_SOURCE[0]}" -eq "${0}" ]; then
    module_XX_name
fi
```

2. Add to `setup-workstation.sh`:
```bash
run_module "XX-module-name.sh" "Module Name"
```

## 📄 License

This project maintains the same license as the original monolithic script.

## 🙏 Credits

Decoupled from the original monolithic Fedora workstation setup script for better maintainability and modularity.
