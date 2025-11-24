# Fedora 43 DevOps & Cloud Engineer Setup Suite

> A comprehensive, production-ready collection of installation scripts for setting up a complete DevOps, Cloud Engineering, and Development environment on Fedora 43 with NVIDIA support.

[![Fedora 43](https://img.shields.io/badge/Fedora-43-51A2DA?logo=fedora)](https://fedoraproject.org/)
[![Shell Script](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎯 Overview

This suite provides **10 specialized installation scripts** covering every aspect of a modern cloud/DevOps engineer's toolkit, from system foundation to productivity tools. Each script is:

- ✅ **Robust** - Comprehensive error handling and logging
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Interactive** - Prompts for optional components
- ✅ **Logged** - Detailed logs for troubleshooting
- ✅ **User-friendly** - Color-coded output and progress tracking

## 📦 What's Included

### Installation Categories

| Script | Category | Key Tools |
|--------|----------|-----------|
| **01** | System Foundation | NVIDIA drivers, RPM Fusion, system utilities, DNF optimization |
| **02** | Terminal & Shell | Alacritty, Kitty, Zsh, Oh-My-Zsh, exa, bat, ripgrep, fzf, starship |
| **03** | Containers & Orchestration | Podman, Docker, kubectl, Helm, k9s, Minikube, Kind, Trivy, Grype |
| **04** | Cloud Providers | AWS CLI, Azure CLI, GCloud SDK, Terraform, Terragrunt, Pulumi, OpenTofu |
| **05** | IaC & Config Management | Ansible, Packer, Vagrant, Libvirt/KVM, Puppet, Salt, Chef |
| **06** | Networking Tools | Wireshark, tcpdump, nmap, WireGuard, Tailscale, HAProxy, Nginx, Istio |
| **07** | Development Tools | Python, Go, Node.js, Rust, Ruby, Java, .NET, VSCode, linters |
| **08** | Monitoring & Observability | Prometheus, Grafana, Loki, Jaeger, Netdata, Telegraf, OpenTelemetry |
| **09** | Security & Secrets | Vault, SOPS, age, Trivy, Lynis, ClamAV, certbot, mkcert, OpenSCAP |
| **10** | Productivity & Desktop | Browsers, Flatpak, fonts, themes, Cockpit, Flameshot, OBS, communication apps |

## 🚀 Quick Start

### Prerequisites

- Fedora 43 (freshly installed recommended)
- Sudo privileges
- Internet connection
- At least 20GB free disk space

### Basic Installation

```bash
# Clone or download all scripts to a directory
cd ~/Downloads/fedora-setup

# Make all scripts executable
chmod +x *.sh

# Run the master installer
./00-master-installer.sh
```

### Master Installer Options

The master installer provides an interactive menu:

```
00. Install ALL (Full Setup)        - Complete installation of all categories
88. Install Custom Selection        - Choose specific categories
01-10. Individual Categories        - Install one category at a time
99. Exit
```

### Individual Script Usage

You can also run individual scripts directly:

```bash
# Install system foundation (recommended first)
./01-system-foundation.sh

# Install containers and Kubernetes tools
./03-containers-orchestration.sh

# Install cloud provider CLIs
./04-cloud-providers.sh
```

## 📋 Detailed Installation Guide

### Recommended Installation Order

For a clean setup, follow this order:

1. **System Foundation** (01) - Sets up base system, NVIDIA drivers
2. **Terminal & Shell** (02) - Modern CLI environment
3. **Development Tools** (07) - Programming languages and editors
4. **Containers** (03) - Container runtimes and Kubernetes
5. **Cloud Providers** (04) - Cloud CLI tools
6. **IaC & Config Management** (05) - Infrastructure automation
7. **Networking** (06) - Network analysis and tools
8. **Monitoring** (08) - Observability stack
9. **Security** (09) - Security and secrets management
10. **Productivity** (10) - Desktop and productivity tools

### Full Installation Example

```bash
# Option 1: Run master installer and select "00. Install ALL"
./00-master-installer.sh

# Option 2: Run individual scripts in sequence
./01-system-foundation.sh
./02-terminal-shell.sh
./03-containers-orchestration.sh
./04-cloud-providers.sh
./05-iac-config-mgmt.sh
./06-networking-tools.sh
./07-development-tools.sh
./08-monitoring-observability.sh
./09-security-secrets.sh
./10-productivity-desktop.sh
```

## 🔧 Post-Installation Steps

### Essential Next Steps

1. **Restart your system** (required for NVIDIA drivers and group memberships)
   ```bash
   sudo reboot
   ```

2. **Verify installations**
   ```bash
   # Check NVIDIA driver
   nvidia-smi
   
   # Check container runtime
   podman --version
   docker --version
   
   # Check Kubernetes tools
   kubectl version --client
   helm version
   
   # Check cloud CLIs
   aws --version
   az --version
   gcloud --version
   ```

3. **Configure cloud credentials**
   ```bash
   # AWS
   aws configure
   
   # Azure
   az login
   
   # Google Cloud
   gcloud init
   ```

4. **Setup shell environment**
   ```bash
   # Switch to zsh (optional but recommended)
   chsh -s /usr/bin/zsh
   
   # Apply shell configurations from:
   # ~/.fedora-setup-shell-config.txt
   ```

5. **Review logs**
   ```bash
   # All logs are stored in:
   ls -lh ~/.fedora-setup-logs/
   
   # View master installer log
   less ~/.fedora-setup-logs/00-master-installer-*.log
   ```

### Configuration Files

Key configuration locations:

- **Logs**: `~/.fedora-setup-logs/`
- **Shell configs**: `~/.zshrc`, `~/.bashrc`
- **Shell hints**: `~/.fedora-setup-shell-config.txt`
- **Ansible**: `~/.ansible/`
- **Kubernetes**: `~/.kube/config`
- **Cloud CLIs**: `~/.aws/`, `~/.azure/`, `~/.config/gcloud/`
- **Systemd examples**: `~/.fedora-setup-systemd-examples/`

## 📊 Script Features

### Robust Error Handling

- Comprehensive error checking for every operation
- Graceful failure handling - continues even if individual packages fail
- Detailed error messages with context

### Comprehensive Logging

```bash
# View all installation logs
ls ~/.fedora-setup-logs/

# Each script creates a timestamped log:
# 01-system-foundation-20250524-143022.log
# 02-terminal-shell-20250524-144530.log
# etc.
```

### Safety Features

- **Non-root execution**: Scripts run as user, elevate with sudo only when needed
- **Idempotent**: Safe to run multiple times
- **Backup creation**: Configuration files backed up before modification
- **Disk space check**: Verifies sufficient space before installation
- **Version verification**: Confirms Fedora 43 before proceeding

### User Experience

- Color-coded output (green for success, red for errors, yellow for warnings)
- Progress indicators for long-running operations
- Interactive prompts for optional components
- Clear next-steps guidance after each script

## 🛠️ Advanced Usage

### Custom Installation

Create your own installation sequence:

```bash
#!/bin/bash
# my-custom-setup.sh

# Install only what I need
./01-system-foundation.sh
./02-terminal-shell.sh
./03-containers-orchestration.sh
./07-development-tools.sh
```

### Automated/Silent Installation

For automation, you can pre-answer prompts:

```bash
# Example: Install Docker without prompting
yes | ./03-containers-orchestration.sh

# Or use expect for more complex automation
```

### Customizing Scripts

Each script is well-commented and modular. To customize:

1. Copy the script you want to modify
2. Edit the package lists or installation logic
3. Run your modified version

Example:

```bash
cp 07-development-tools.sh 07-development-tools-custom.sh
# Edit to add/remove languages or tools
vim 07-development-tools-custom.sh
./07-development-tools-custom.sh
```

## 🔍 Troubleshooting

### Common Issues

**Issue: Script fails with "permission denied"**
```bash
# Solution: Make scripts executable
chmod +x *.sh
```

**Issue: dnf5 command not found**
```bash
# Fedora 43 should have dnf5 by default
# If not, the scripts will fail with clear error messages
sudo dnf install dnf5
```

**Issue: NVIDIA driver installation fails**
```bash
# Check if NVIDIA GPU is detected
lspci | grep -i nvidia

# Review the detailed log
cat ~/.fedora-setup-logs/01-system-foundation-*.log
```

**Issue: Docker daemon not starting**
```bash
# Check status
sudo systemctl status docker

# View logs
sudo journalctl -xeu docker

# Restart service
sudo systemctl restart docker
```

**Issue: Package not found**
```bash
# Some packages may not be available in standard repos
# Check if RPM Fusion is enabled
dnf repolist | grep fusion

# Enable RPM Fusion if missing
sudo dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

### Getting Help

1. **Check the logs**: Detailed logs in `~/.fedora-setup-logs/`
2. **Review script output**: Color-coded warnings and errors
3. **Read next steps**: Each script provides guidance
4. **Check documentation**: Individual tool documentation

## 📚 What Gets Installed

### Complete Tool List

<details>
<summary><b>System Foundation (01)</b></summary>

- NVIDIA drivers (akmod-nvidia, CUDA support)
- RPM Fusion repositories
- System utilities: htop, btop, glances, powertop, tlp
- Performance tools: tuned, numactl, stress
- Monitoring: lm_sensors, smartmontools, nvme-cli
- DNF optimizations

</details>

<details>
<summary><b>Terminal & Shell (02)</b></summary>

- Terminal emulators: Alacritty, Kitty
- Multiplexers: tmux, screen, byobu
- Shells: zsh, fish
- Modern CLI: exa, bat, fd, ripgrep, fzf, zoxide
- Prompt: starship
- Oh-My-Zsh with plugins
- Shell history: mcfly, thefuck

</details>

<details>
<summary><b>Containers & Orchestration (03)</b></summary>

- Podman ecosystem: podman, buildah, skopeo, crun
- Docker Engine (optional)
- Kubernetes: kubectl, helm, k9s, kubectx, kubens
- Local clusters: minikube, kind
- Tools: kustomize, stern
- Security: trivy, grype, syft

</details>

<details>
<summary><b>Cloud Providers (04)</b></summary>

- AWS: CLI v2, eksctl, aws-vault, Session Manager
- Azure: CLI, azcopy
- Google Cloud: SDK, gke-auth-plugin
- IaC: Terraform, terraform-docs, tflint, tfsec, terragrunt
- Alternatives: OpenTofu, Pulumi
- Utilities: cloud-nuke, steampipe

</details>

<details>
<summary><b>IaC & Config Management (05)</b></summary>

- Ansible with ansible-lint, molecule
- Packer
- Vagrant with vagrant-libvirt
- Virtualization: libvirt, KVM, virt-manager
- Puppet (optional)
- SaltStack (optional)
- Chef Workstation (optional)

</details>

<details>
<summary><b>Networking Tools (06)</b></summary>

- Analysis: wireshark, tcpdump, nmap, mtr, iperf3
- DNS: dnsmasq, unbound, consul, etcd
- Proxies: haproxy, nginx, traefik, caddy
- VPN: wireguard, openvpn, tailscale, cloudflared
- Security: firewalld, fail2ban
- Monitoring: iftop, nethogs, bandwhich
- Service mesh: Istio, Linkerd (optional)

</details>

<details>
<summary><b>Development Tools (07)</b></summary>

- Languages: Python, Go, Node.js, Rust, Ruby, Java, .NET
- Editors: Neovim, Vim, VSCode (optional), Emacs (optional)
- Build tools: make, cmake, gcc, gdb, valgrind
- Linters: shellcheck, yamllint, hadolint, pylint, flake8, black
- API tools: httpie, curl, jq, yq, grpcurl
- Version managers: nvm, poetry

</details>

<details>
<summary><b>Monitoring & Observability (08)</b></summary>

- Metrics: Prometheus, node_exporter, Grafana
- Logging: Loki, Promtail, Vector
- Tracing: Jaeger, OpenTelemetry Collector
- Agents: Telegraf, Grafana Agent
- Real-time: Netdata
- Systemd service templates

</details>

<details>
<summary><b>Security & Secrets (09)</b></summary>

- Secrets: Vault, SOPS, age, pass, kubeseal
- Security: Lynis, ClamAV, rkhunter, chkrootkit, nuclei
- Certificates: certbot, cfssl, step-cli, mkcert
- IDS: AIDE
- Compliance: OpenSCAP
- Security scan automation script

</details>

<details>
<summary><b>Productivity & Desktop (10)</b></summary>

- Browsers: Firefox, Chrome (optional), Chromium (optional)
- Screenshots: Flameshot, OBS Studio, Peek, Kazam
- Fonts: Noto, Fira Code, JetBrains Mono, FontAwesome
- Themes: Papirus icons, Arc theme
- System: Cockpit web interface
- Flatpak with Flathub
- Communication: Slack, Discord, Zoom (optional, via Flatpak)
- Documentation: Pandoc, GraphViz, Hugo
- Utilities: tree, ncdu, duf, dust, procs, bottom

</details>

## 🎓 Learning Resources

### Understanding the Stack

- **Containers**: Learn Podman vs Docker differences
- **Kubernetes**: Start with Minikube for local development
- **Cloud**: Configure one cloud provider at a time
- **IaC**: Begin with Terraform basics
- **Monitoring**: Set up Prometheus + Grafana stack
- **Security**: Run regular security scans with provided script

### Recommended Configurations

**Shell Configuration (zsh)**:
```bash
# Add to ~/.zshrc
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(mcfly init zsh)"

# Aliases
alias ls='exa'
alias cat='bat'
alias find='fd'
alias grep='rg'
```

**Kubectl Aliases**:
```bash
# Add to ~/.zshrc or ~/.bashrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
```

**Docker/Podman Aliases**:
```bash
alias d='docker'
alias dc='docker-compose'
alias p='podman'
alias pc='podman-compose'
```

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Test changes on a fresh Fedora 43 installation
2. Ensure all error handling is maintained
3. Update logging as needed
4. Follow existing script structure
5. Update this README if adding new categories

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

These scripts modify your system configuration and install numerous packages. While designed to be safe and robust:

- **Always review scripts before running**
- **Test in a VM first if possible**
- **Backup important data before major installations**
- **Review logs for any errors or warnings**

The scripts are provided "as is" without warranty of any kind.

## 🙏 Acknowledgments

- Fedora Project for an excellent development platform
- All the amazing open-source projects included in these scripts
- The DevOps and Cloud Native communities

## 📮 Support

For issues, questions, or suggestions:

1. Check the troubleshooting section above
2. Review the detailed logs in `~/.fedora-setup-logs/`
3. Consult individual tool documentation
4. Create an issue with relevant log excerpts

---

**Made with ❤️ for Cloud and DevOps Engineers**

*Last updated: November 2025*
