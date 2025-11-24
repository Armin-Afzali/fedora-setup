#!/bin/bash

#############################################
# Fedora 43 Setup - Monitoring & Observability
# Description: Prometheus, Grafana, logging, tracing, APM
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
LOG_FILE="${LOG_DIR}/08-monitoring-observability-$(date +%Y%m%d-%H%M%S).log"
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

# Install Prometheus
install_prometheus() {
    print_header "Installing Prometheus"
    
    if ! command -v prometheus &>/dev/null; then
        print_info "Downloading Prometheus..."
        local version=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        cd /tmp
        curl -LO "https://github.com/prometheus/prometheus/releases/download/v${version}/prometheus-${version}.linux-amd64.tar.gz" 2>&1 | tee -a "${LOG_FILE}"
        tar xvf prometheus-${version}.linux-amd64.tar.gz
        
        sudo cp prometheus-${version}.linux-amd64/prometheus /usr/local/bin/
        sudo cp prometheus-${version}.linux-amd64/promtool /usr/local/bin/
        
        # Create prometheus user and directories
        sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
        sudo mkdir -p /etc/prometheus /var/lib/prometheus
        sudo cp -r prometheus-${version}.linux-amd64/consoles /etc/prometheus
        sudo cp -r prometheus-${version}.linux-amd64/console_libraries /etc/prometheus
        sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
        
        rm -rf prometheus-${version}.linux-amd64*
        print_success "Prometheus installed"
    else
        print_info "Prometheus already installed"
    fi
}

# Install node_exporter
install_node_exporter() {
    print_header "Installing Node Exporter"
    
    if ! command -v node_exporter &>/dev/null; then
        print_info "Downloading Node Exporter..."
        local version=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        cd /tmp
        curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${version}/node_exporter-${version}.linux-amd64.tar.gz" 2>&1 | tee -a "${LOG_FILE}"
        tar xvf node_exporter-${version}.linux-amd64.tar.gz
        sudo cp node_exporter-${version}.linux-amd64/node_exporter /usr/local/bin/
        rm -rf node_exporter-${version}.linux-amd64*
        print_success "Node Exporter installed"
    else
        print_info "Node Exporter already installed"
    fi
}

# Install Grafana
install_grafana() {
    print_header "Installing Grafana"
    
    if ! command -v grafana-server &>/dev/null; then
        print_info "Adding Grafana repository..."
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
        
        print_info "Installing Grafana..."
        sudo dnf5 install -y grafana 2>&1 | tee -a "${LOG_FILE}"
        print_success "Grafana installed"
    else
        print_info "Grafana already installed"
    fi
}

# Install Loki
install_loki() {
    print_header "Installing Loki and Promtail"
    
    if ! command -v loki &>/dev/null; then
        print_info "Downloading Loki..."
        local version=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        sudo curl -L "https://github.com/grafana/loki/releases/download/v${version}/loki-linux-amd64.zip" -o /tmp/loki.zip 2>&1 | tee -a "${LOG_FILE}"
        cd /tmp
        unzip loki.zip
        sudo mv loki-linux-amd64 /usr/local/bin/loki
        sudo chmod +x /usr/local/bin/loki
        rm loki.zip
        print_success "Loki installed"
    else
        print_info "Loki already installed"
    fi
    
    if ! command -v promtail &>/dev/null; then
        print_info "Downloading Promtail..."
        local version=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        sudo curl -L "https://github.com/grafana/loki/releases/download/v${version}/promtail-linux-amd64.zip" -o /tmp/promtail.zip 2>&1 | tee -a "${LOG_FILE}"
        cd /tmp
        unzip promtail.zip
        sudo mv promtail-linux-amd64 /usr/local/bin/promtail
        sudo chmod +x /usr/local/bin/promtail
        rm promtail.zip
        print_success "Promtail installed"
    else
        print_info "Promtail already installed"
    fi
}

# Install Jaeger
install_jaeger() {
    print_header "Installing Jaeger"
    
    if ! command -v jaeger-all-in-one &>/dev/null; then
        print_info "Downloading Jaeger..."
        local version=$(curl -s https://api.github.com/repos/jaegertracing/jaeger/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        cd /tmp
        curl -LO "https://github.com/jaegertracing/jaeger/releases/download/v${version}/jaeger-${version}-linux-amd64.tar.gz" 2>&1 | tee -a "${LOG_FILE}"
        tar xvf jaeger-${version}-linux-amd64.tar.gz
        sudo cp jaeger-${version}-linux-amd64/jaeger-* /usr/local/bin/
        rm -rf jaeger-${version}-linux-amd64*
        print_success "Jaeger installed"
    else
        print_info "Jaeger already installed"
    fi
}

# Install Netdata
install_netdata() {
    print_header "Installing Netdata"
    
    if ! command -v netdata &>/dev/null; then
        print_info "Installing Netdata..."
        bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait 2>&1 | tee -a "${LOG_FILE}" || print_warning "Netdata installation may have failed"
        print_success "Netdata installed"
        print_info "Access Netdata at: http://localhost:19999"
    else
        print_info "Netdata already installed"
    fi
}

# Install Vector
install_vector() {
    print_header "Installing Vector"
    
    if ! command -v vector &>/dev/null; then
        print_info "Installing Vector..."
        curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash 2>&1 | tee -a "${LOG_FILE}" || print_warning "Vector installation may have failed"
        print_success "Vector installed"
    else
        print_info "Vector already installed"
    fi
}

# Install Telegraf
install_telegraf() {
    print_header "Installing Telegraf"
    
    if ! command -v telegraf &>/dev/null; then
        print_info "Adding InfluxData repository..."
        cat <<EOF | sudo tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF
        
        print_info "Installing Telegraf..."
        sudo dnf5 install -y telegraf 2>&1 | tee -a "${LOG_FILE}"
        print_success "Telegraf installed"
    else
        print_info "Telegraf already installed"
    fi
}

# Install OpenTelemetry Collector
install_otel_collector() {
    print_header "Installing OpenTelemetry Collector"
    
    if ! command -v otelcol &>/dev/null; then
        print_info "Downloading OpenTelemetry Collector..."
        local version=$(curl -s https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        cd /tmp
        curl -LO "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${version}/otelcol_${version}_linux_amd64.tar.gz" 2>&1 | tee -a "${LOG_FILE}"
        tar xvf otelcol_${version}_linux_amd64.tar.gz
        sudo cp otelcol /usr/local/bin/
        rm otelcol_${version}_linux_amd64.tar.gz otelcol
        print_success "OpenTelemetry Collector installed"
    else
        print_info "OpenTelemetry Collector already installed"
    fi
}

# Create systemd service examples
create_service_examples() {
    print_header "Creating Systemd Service Examples"
    
    local examples_dir="${HOME}/.fedora-setup-systemd-examples"
    mkdir -p "$examples_dir"
    
    # Prometheus service example
    cat > "${examples_dir}/prometheus.service" <<'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
    
    # Node Exporter service example
    cat > "${examples_dir}/node_exporter.service" <<'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Systemd service examples created at: ${examples_dir}"
    print_info "Copy to /etc/systemd/system/ and enable with: sudo systemctl enable --now <service>"
}

# Main execution
main() {
    print_header "Fedora 43 Monitoring & Observability Setup"
    print_info "Log file: ${LOG_FILE}"
    
    check_root
    check_sudo
    
    # Ask which components to install
    read -p "Install Prometheus stack (Prometheus, Node Exporter)? (y/n) " -n 1 -r install_prom
    echo
    read -p "Install Grafana? (y/n) " -n 1 -r install_graf
    echo
    read -p "Install Loki & Promtail (log aggregation)? (y/n) " -n 1 -r install_loki_tool
    echo
    read -p "Install Jaeger (tracing)? (y/n) " -n 1 -r install_jaeger_tool
    echo
    read -p "Install Netdata (real-time monitoring)? (y/n) " -n 1 -r install_netdata_tool
    echo
    
    [[ $install_prom =~ ^[Yy]$ ]] && install_prometheus && install_node_exporter
    [[ $install_graf =~ ^[Yy]$ ]] && install_grafana
    [[ $install_loki_tool =~ ^[Yy]$ ]] && install_loki
    [[ $install_jaeger_tool =~ ^[Yy]$ ]] && install_jaeger
    [[ $install_netdata_tool =~ ^[Yy]$ ]] && install_netdata
    
    install_telegraf
    install_vector
    install_otel_collector
    create_service_examples
    
    print_header "Installation Summary"
    print_success "Monitoring & Observability setup completed!"
    print_info "Log file saved to: ${LOG_FILE}"
    
    print_info "\nInstalled Tools:"
    [[ $install_prom =~ ^[Yy]$ ]] && echo "  - Prometheus & Node Exporter"
    [[ $install_graf =~ ^[Yy]$ ]] && echo "  - Grafana"
    [[ $install_loki_tool =~ ^[Yy]$ ]] && echo "  - Loki & Promtail"
    [[ $install_jaeger_tool =~ ^[Yy]$ ]] && echo "  - Jaeger"
    [[ $install_netdata_tool =~ ^[Yy]$ ]] && echo "  - Netdata"
    echo "  - Telegraf"
    echo "  - Vector"
    echo "  - OpenTelemetry Collector"
    
    print_info "\nNext Steps:"
    echo "1. Review systemd service examples: ${HOME}/.fedora-setup-systemd-examples"
    echo "2. Configure and start services as needed"
    [[ $install_prom =~ ^[Yy]$ ]] && echo "3. Configure Prometheus: /etc/prometheus/prometheus.yml"
    [[ $install_graf =~ ^[Yy]$ ]] && echo "4. Start Grafana: sudo systemctl enable --now grafana-server"
    [[ $install_netdata_tool =~ ^[Yy]$ ]] && echo "5. Access Netdata: http://localhost:19999"
    
    print_info "\nReview the log file for any warnings or errors"
}

main "$@"
